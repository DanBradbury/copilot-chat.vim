function! copilot_chat#open_chat()
  call copilot_chat#config#load()
  call copilot_chat#auth#verify_signin()
  let g:active_chat_buffer = copilot_chat#buffer#create()

  normal! G
endfunction

function! copilot_chat#submit_message()
  let l:separator_line = search(' ━\+$', 'nw')
  let l:start_line = l:separator_line + 1
  let l:end_line = line('$')

  let l:lines = getline(l:start_line, l:end_line)

  for l:i in range(len(l:lines))
    let l:line = l:lines[l:i]
    if l:line =~? '^> \(\w\+\)'
      let l:text = matchstr(l:line, '^> \(\w\+\)')
      let l:text = substitute(l:text, '^> ', '', '')
      if has_key(s:prompts, l:text)
        let l:lines[l:i] = s:prompts[l:text]
      endif
    endif
  endfor
  let l:message = join(l:lines, "\n")

  call copilot_chat#api#async_request(l:message)
endfunction

function! copilot_chat#http(method, url, headers, body)
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
