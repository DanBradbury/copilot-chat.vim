scriptencoding utf-8

let s:curl_output = []

function! copilot_chat#api#async_request(message) abort
  let l:chat_token = copilot_chat#auth#verify_signin()
  let s:curl_output = []
  let l:url = 'https://api.githubcopilot.com/chat/completions'

  " for knowledge bases its just an attachment as the content
  "{'content': '<attachment id="kb:Name">\n#kb:\n</attachment>', 'role': 'user'}
  " for files similar
  let l:messages = [{'content': a:message, 'role': 'user'}]
  let l:data = json_encode({
        \ 'intent': v:false,
        \ 'model': g:copilot_chat_default_model,
        \ 'temperature': 0,
        \ 'top_p': 1,
        \ 'n': 1,
        \ 'stream': v:true,
        \ 'messages': l:messages
        \ })

  let l:curl_cmd = [
        \ 'curl',
        \ '-s',
        \ '-X',
        \ 'POST',
        \ '-H',
        \ 'Content-Type: application/json',
        \ '-H', 'Authorization: Bearer ' . l:chat_token,
        \ '-H', 'Editor-Version: vscode/1.80.1',
        \ '-d',
        \ l:data,
        \ l:url]

  let job = job_start(l:curl_cmd, {'out_cb': function('copilot_chat#api#handle_job_output'), 'exit_cb': function('copilot_chat#api#handle_job_close'), 'err_cb': function('copilot_chat#api#handle_job_error')})
  call copilot_chat#buffer#waiting_for_response()
  return job
endfunction

function! copilot_chat#api#handle_job_output(channel, msg) abort
  call add(s:curl_output, a:msg)
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

  let l:width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
  let l:separator = ' '
  let l:separator .= repeat('━', l:width)
  call copilot_chat#buffer#append_message(l:separator)
  call copilot_chat#buffer#append_message(split(l:result, "\n"))
  call copilot_chat#buffer#add_input_separator()
endfunction

function! copilot_chat#api#handle_job_error(channel, msg) abort
  echom 'handling curl error'
  echom a:msg
endfunction

function! copilot_chat#api#fetch_models(chat_token) abort
  let l:chat_headers = [
    \ 'Content-Type: application/json',
    \ 'Authorization: Bearer ' . a:chat_token,
    \ 'Editor-Version: vscode/1.80.1'
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
    let g:copilot_chat_available_models = l:model_list
  endtry

  return l:response
endfunction

" vim:set ft=vim sw=2 sts=2 et:
