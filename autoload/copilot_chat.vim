scriptencoding utf-8

function! copilot_chat#open_chat() abort
  if copilot_chat#auth#verify_signin() != v:null
    if copilot_chat#buffer#has_active_chat() &&
       \  g:copilot_reuse_active_chat == 1
      call copilot_chat#buffer#focus_active_chat()
    else
      call copilot_chat#buffer#create()
    normal! G
    endif
  endif
endfunction

function! copilot_chat#start_chat(message) abort
  call copilot_chat#open_chat()
  call copilot_chat#buffer#append_message(a:message)
  call copilot_chat#api#async_request([{'content': a:message, 'role': 'user'}], [])
endfunction

function! copilot_chat#reset_chat() abort
  if g:copilot_chat_active_buffer == -1 || !bufexists(g:copilot_chat_active_buffer)
    echom 'No active chat window to reset'
    return
  endif

  let l:current_buf = bufnr('%')

  " Switch to the active chat buffer if not already there
  if l:current_buf != g:copilot_chat_active_buffer
    execute 'buffer ' . g:copilot_chat_active_buffer
  endif

  silent! %delete _

  call copilot_chat#buffer#welcome_message()

  normal! G

  if l:current_buf != g:copilot_chat_active_buffer && bufexists(l:current_buf)
    execute 'buffer ' . l:current_buf
  endif
endfunction

function! copilot_chat#submit_message() abort
  let l:messages = []
  let l:responses = []
  let l:pattern = ' ━\+$'
  let l:all_file_lists = []
  call cursor(1,1)

  while search(l:pattern, 'W') > 0
    let l:header_line = getline('.')
    let l:role = 'user'
    " Check separator icon to determine message role
    " Separator with  icon indicates assistant response, otherwise user message
    if stridx(l:header_line, ' ') != -1
      let l:role = 'assistant'
    endif
    let l:start_line = line('.') + 1
    let l:end_line = search(l:pattern, 'W')
    if l:end_line == 0
      let l:end_line = line('$')
    else
      let l:end_line -= 1
      call cursor(line('.')-1, col('.'))
    endif

    let l:lines = getline(l:start_line, l:end_line)
    let l:file_list = []

    for l:i in range(len(l:lines))
      let l:line = l:lines[l:i]
      if l:line =~? '^> \(\w\+\)'
        let l:text = matchstr(l:line, '^> \(\w\+\)')
        let l:text = substitute(l:text, '^> ', '', '')
        if has_key(g:copilot_chat_prompts, l:text)
          let l:lines[l:i] = g:copilot_chat_prompts[l:text]
        endif
      elseif l:line =~? '^#file:'
        let l:filename = matchstr(l:line, '^#file:\s*\zs.*\ze$')
        call add(l:file_list, l:filename)
      endif
    endfor
    let l:message = join(l:lines, "\n")

    call add(l:messages, {'content': l:message, 'role': l:role})
    call add(l:all_file_lists, l:file_list)
    call cursor(line('.'), col('.') + 1)
  endwhile

  " Limit message history to improve performance
  " Only send the most recent messages based on configuration
  let l:limit = g:copilot_chat_message_history_limit
  if len(l:messages) > l:limit && l:limit > 0
    let l:start_idx = len(l:messages) - l:limit
    let l:messages = l:messages[l:start_idx :]
    let l:all_file_lists = l:all_file_lists[l:start_idx :]
  endif

  " Consolidate file lists from recent messages
  " O(n) consolidation using dictionary for O(1) duplicate detection (improved from O(n²))
  let l:consolidated_files = []
  let l:seen = {}
  for l:files in l:all_file_lists
    for l:file in l:files
      if !has_key(l:seen, l:file)
        let l:seen[l:file] = 1
        call add(l:consolidated_files, l:file)
      endif
    endfor
  endfor

  call copilot_chat#api#async_request(l:messages, l:consolidated_files)
endfunction


function! copilot_chat#http(method, url, headers, body) abort
  if has('win32')
    let l:ps_cmd = 'powershell -Command "'
    let l:ps_cmd .= '$headers = @{'
    for header in a:headers
      let [key, value] = split(header, ': ')
      let l:ps_cmd .= "'" . key . "'='" . value . "';"
    endfor
    let l:ps_cmd .= '};'
    if a:method !=# 'GET'
      let l:ps_cmd .= '$body = ConvertTo-Json @{'
      for obj in keys(a:body)
        let l:ps_cmd .= obj . "='" . a:body[obj] . "';"
      endfor
      let l:ps_cmd .= '};'
    endif
    let l:ps_cmd .= "Invoke-WebRequest -Uri '" . a:url . "' -Method " .a:method . " -Headers $headers -Body $body -ContentType 'application/json' | Select-Object -ExpandProperty Content"
    let l:ps_cmd .= '"'
    let l:response = system(l:ps_cmd)
  else
    let l:token_data = json_encode(a:body)

    let l:curl_cmd = 'curl -s -X ' . a:method . ' --compressed '
    for header in a:headers
      let l:curl_cmd .= '-H "' . header . '" '
    endfor
    let l:curl_cmd .= "-d '" . l:token_data . "' " . a:url

    let l:response = system(l:curl_cmd)
    if v:shell_error != 0
      echom 'Error: ' . v:shell_error
      return ''
    endif
  endif
  return l:response
endfunction

" vim:set ft=vim sw=2 sts=2 et:
