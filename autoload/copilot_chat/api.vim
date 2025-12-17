scriptencoding utf-8

let s:curl_output = []

function! copilot_chat#api#async_request(messages, file_list) abort
  let l:chat_token = copilot_chat#auth#verify_signin()
  let s:curl_output = []
  let l:url = 'https://api.githubcopilot.com/chat/completions'

  " for knowledge bases its just an attachment as the content
  "{'content': '<attachment id="kb:Name">\n#kb:\n</attachment>', 'role': 'user'}
  " for files similar
  for file in a:file_list
    let l:file_content = readfile(file)
    let full_path = fnamemodify(file, ':p')
    " TODO: get the filetype instead of just markdown
    let l:c = '<attachment id="' . file . '">\n````markdown\n<!-- filepath: ' . full_path . ' -->\n' . join(l:file_content, "\n") . '\n```</attachment>'
    call add(a:messages, {'content': l:c, 'role': 'user'})
  endfor

  let l:data = json_encode({
        \ 'intent': v:false,
        \ 'model': copilot_chat#models#current(),
        \ 'temperature': 0,
        \ 'top_p': 1,
        \ 'n': 1,
        \ 'stream': v:true,
        \ 'messages': a:messages
        \ })

  let tmpfile = tempname()
  call writefile([l:data], tmpfile)

  let l:curl_cmd = [
        \ 'curl',
        \ '-s',
        \ '-X',
        \ 'POST',
        \ '-H',
        \ 'Content-Type: application/json',
        \ '-H', 'Authorization: Bearer ' . l:chat_token,
        \ '-H', 'Editor-Version: vscode/1.107.0',
        \ '-H', 'Editor-Plugin-Version: copilot-chat/0.36.2025121601',
        \ '-d',
        \ '@' . tmpfile,
        \ l:url]

  if has('nvim')
    let job = jobstart(l:curl_cmd, {
      \ 'on_stdout': {chan_id, data, name->copilot_chat#api#handle_job_output(chan_id, data)},
      \ 'on_exit': {chan_id, data, name->copilot_chat#api#handle_job_close(chan_id, data)},
      \ 'on_stderr': {chan_id, data, name->copilot_chat#api#handle_job_error(chan_id, data)},
      \ 'stdout_buffered': v:true,
      \ 'stderr_buffered': v:true
      \ })
  else
    let job = job_start(l:curl_cmd, {
      \ 'out_cb': function('copilot_chat#api#handle_job_output'),
      \ 'exit_cb': function('copilot_chat#api#handle_job_close'),
      \ 'err_cb': function('copilot_chat#api#handle_job_error')
      \ })
  endif
  call copilot_chat#buffer#waiting_for_response()

  return job
endfunction

function! copilot_chat#api#handle_job_output(channel, msg) abort
  if type(a:msg) == v:t_list
    for data in a:msg
      if data =~? '^data: {'
        call add(s:curl_output, data)
      endif
    endfor
  else
    call add(s:curl_output, a:msg)
  endif
endfunction

function! copilot_chat#api#handle_job_close(channel, msg) abort
  call deletebufline(g:copilot_chat_active_buffer, '$')
  let l:result = ''
  for line in s:curl_output
    if line =~? '^data: {'
      let l:json_completion = json_decode(line[6:])
      try
        let l:content = l:json_completion.choices[0].delta.content
        if type(l:content) != type(v:null)
          let l:result .= l:content
        endif
      catch
        let l:result .= "\n"
      endtry
    endif
  endfor

  let l:response = split(l:result, "\n")
  let l:width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff

  let l:separator = ' '
  let l:separator .= repeat('━', l:width)
  let l:response_start = line('$') + 1

  call copilot_chat#buffer#append_message(l:separator)
  call copilot_chat#buffer#append_message(l:response)
  call copilot_chat#buffer#add_input_separator()

  let l:wrap_width = l:width + 2
  let l:softwrap_lines = 0
  for line in l:response
    if strwidth(line) > l:wrap_width
      let l:softwrap_lines += ceil(strwidth(line) / l:wrap_width)
    else
      let l:softwrap_lines += 1
    endif
  endfor

  let l:total_response_length = l:softwrap_lines + 2
  let l:height = winheight(0)
  if l:total_response_length >= l:height
    execute 'normal! ' . l:response_start . 'Gzt'
  else
    execute 'normal! G'
  endif
  call setcursorcharpos(0, 3)

endfunction

function! copilot_chat#api#handle_job_error(channel, msg) abort
  if type(a:msg) == v:t_list
    let l:filtered_errors = filter(copy(a:msg), '!empty(v:val)')
    if len(l:filtered_errors) > 0
      echom l:filtered_errors
    endif
  else
    echom a:msg
  endif
endfunction

function! copilot_chat#api#fetch_models(chat_token) abort
  let l:chat_headers = [
    \ 'Authorization: Bearer ' . a:chat_token,
    \ 'Editor-Version: vscode/1.107.0',
    \ 'Editor-Plugin-Version: copilot-chat/0.36.2025121601',
    \ ]

  let l:response = copilot_chat#http('GET', 'https://api.githubcopilot.com/models', l:chat_headers, {})
  try
    let l:json_response = json_decode(l:response)
    let l:model_list = []
    for item in l:json_response.data
        if has_key(item, 'id')
            call add(l:model_list, item.id)
        endif
    endfor
    return l:model_list
  endtry

  return l:response
endfunction

" vim:set ft=vim sw=2 sts=2 et:
