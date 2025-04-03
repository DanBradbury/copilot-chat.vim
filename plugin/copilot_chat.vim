scriptencoding utf-8

let s:config_dir = expand('~/.vim/copilot-chat')
let s:device_token_file = s:config_dir . '/.device_token'
let s:chat_token_file = s:config_dir . '/.chat_token'
let s:chat_config_file = s:config_dir . '/config.json'
let s:prompts = {}
let s:token_headers = [
  \ 'Accept: application/json',
  \ 'User-Agent: GithubCopilot/1.155.0',
  \ 'Accept-Encoding: gzip,deflate,br',
  \ 'Editor-Plugin-Version: copilot.vim/1.16.0',
  \ 'Editor-Version: vim/9.0.1',
  \ 'Content-Type: application/json',
  \ ]
let s:chat_buffer = -1
let s:chat_count = 1
let s:default_model = 'gpt-4o'
let s:available_models = []
let s:colors_gui = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
let s:colors_cterm = [46, 118, 154, 190, 226, 227, 228, 229, 230]
let s:color_index = 0

def UserInputSeparator()
  var width = winwidth(0) - 2
  var separator = ' ' .. repeat('━', width)
  call appendbufline(s:chat_buffer, '$', separator)
  call appendbufline(s:chat_buffer, '$', '')
  var win_id = bufwinid(s:chat_buffer)
  if win_id != -1
    call win_execute(win_id, 'normal! G')
  endif
enddef

function! LoadConfig()
  if !isdirectory(s:config_dir)
    call mkdir(s:config_dir, 'p')
  endif
  if filereadable(s:chat_config_file)
    let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
    let s:default_model = l:config.model
    let s:prompts = l:config.prompts
  else
    let l:config = {'model': s:default_model, 'prompts': '[]'}
    call writefile([json_encode(l:config)], s:chat_config_file)
  endif
endfunction

function! ViewConfig()
  execute 'vsplit ' . s:chat_config_file
endfunction

function! ViewModels()
  vsplit
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  call appendbufline(bufnr('%'), 0, 'Available Models:')
  call appendbufline(bufnr('%'), '$', s:available_models)
  execute 'syntax match ActiveModel /^' . s:default_model . '$/'
  execute 'highlight ActiveModel guifg=#33FF33 ctermfg=46'
  nnoremap <buffer> <CR> :SelectModel<CR>
endfunction

function! SelectModel()
  let l:selected_model = getline('.')
  let s:default_model = l:selected_model
  let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
  let l:config.model = l:selected_model
  call writefile([json_encode(l:config)], s:chat_config_file)
endfunction

function ConfirmSignin()
  call FetchModels(GetChatToken(v:true))
endfunction

function! CopilotChat()
  call LoadConfig()
  call ConfirmSignin()
  vsplit
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nonumber
  setlocal norelativenumber
  setlocal wrap
  execute 'file CopilotChat-' . s:chat_count
  let s:chat_count += 1
  let s:chat_buffer = bufnr('%')

  nnoremap <buffer> <leader>cs :SubmitChatMessage<CR>
  nnoremap <buffer> <CR> :SubmitChatMessage<CR>

  syntax match CopilotWelcome /^Welcome to Copilot Chat!.*$/
  syntax match CopilotSeparatorIcon /^/
  syntax match CopilotSeparatorIcon /^/
  syntax match CopilotSeparatorLine / ━\+$/
  syntax match CopilotWaiting /Waiting for response\.*$/
  syntax match CopilotPrompt /^> .*/

  highlight CopilotWaiting ctermfg=46 guifg=#33FF33
  highlight CopilotWelcome ctermfg=205 guifg=#ff69b4
  highlight CopilotSeparatorIcon ctermfg=45 guifg=#00d7ff
  highlight CopilotSeparatorLine ctermfg=205 guifg=#ff69b4
  highlight CopilotPrompt ctermfg=230 guifg=#FFFF33

  if !exists('g:syntax_on')
    syntax enable
  endif

  call appendbufline(s:chat_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  call UserInputSeparator()

  normal! G
endfunction

function! SubmitChatMessage()
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

  call AsyncRequest(l:message)
endfunction

function HttpIt(method, url, headers, body)
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

function! GetDeviceToken()
  let l:token_url = 'https://github.com/login/device/code'
  let l:headers = [
    \ 'Accept: application/json',
    \ 'User-Agent: GithubCopilot/1.155.0',
    \ 'Accept-Encoding: gzip,deflate,br',
    \ 'Editor-Plugin-Version: copilot.vim/1.16.0',
    \ 'Editor-Version: Neovim/0.6.1',
    \ 'Content-Type: application/json',
    \ ]
  let l:data = {
    \ 'client_id': 'Iv1.b507a08c87ecfe98',
    \ 'scope': 'read:user'
    \ }

  return HttpIt('POST', l:token_url, l:headers, l:data)
endfunction

function! GetBearerToken()
  if filereadable(s:device_token_file)
    return join(readfile(s:device_token_file), "\n")
  else
    let l:response = GetDeviceToken()
    let l:json_response = json_decode(l:response)
    let l:device_code = l:json_response.device_code
    let l:user_code = l:json_response.user_code
    let l:verification_uri = l:json_response.verification_uri

    echo 'Please visit ' . l:verification_uri . ' and enter the code: ' . l:user_code
    call input("Press Enter to continue...\n")

    let l:token_poll_url = 'https://github.com/login/oauth/access_token'
    let l:token_poll_data = {
      \ 'client_id': 'Iv1.b507a08c87ecfe98',
      \ 'device_code': l:device_code,
      \ 'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'
      \ }
    let l:access_token_response = HttpIt('POST', l:token_poll_url, s:token_headers, l:token_poll_data)
    let l:json_response = json_decode(l:access_token_response)
    let l:bearer_token = l:json_response.access_token
    call writefile([l:bearer_token], s:device_token_file)

    return l:bearer_token
  endif
endfunction

function! GetChatToken(fetch_new)
  if filereadable(s:chat_token_file) && a:fetch_new == v:false
    return join(readfile(s:chat_token_file), "\n")
  else
    let l:bearer_token = GetBearerToken()
    let l:token_url = 'https://api.github.com/copilot_internal/v2/token'
    let l:token_headers = [
      \ 'Content-Type: application/json',
      \ 'Editor-Version: vscode/1.80.1',
      \ 'Authorization: token ' . l:bearer_token,
      \ ]
    let l:token_data = {
      \ 'client_id': 'Iv1.b507a08c87ecfe98',
      \ 'scope': 'read:user'
      \ }
    let l:response = HttpIt('GET', l:token_url, l:token_headers, l:token_data)
    let l:json_response = json_decode(l:response)
    let l:chat_token = l:json_response.token
    call writefile([l:chat_token], s:chat_token_file)

    return l:chat_token
  endif
endfunction

function! FetchModels(chat_token)
  let l:chat_headers = [
    \ 'Content-Type: application/json',
    \ 'Authorization: Bearer ' . a:chat_token,
    \ 'Editor-Version: vscode/1.80.1'
    \ ]

  let l:response = HttpIt('GET', 'https://api.githubcopilot.com/models', l:chat_headers, {})
  try
    let l:json_response = json_decode(l:response)
    let l:model_list = []
    for item in l:json_response.data
        if has_key(item, 'id')
            call add(l:model_list, item.id)
        endif
    endfor
    let s:available_models = l:model_list
  endtry

  return l:response
endfunction

function! ValidateToken()
  let l:chat_token = GetChatToken(v:false)
  try
    call FetchModels(l:chat_token)
  catch
    let l:chat_token = GetChatToken(v:true)
  endtry
  return l:chat_token
endfunction

function! UpdateWaitingDots()
  let l:current_text = getbufline(s:chat_buffer, '$')[0]
  if l:current_text =~? '^Waiting for response'
      let l:dots = len(matchstr(l:current_text, '\..*$'))
      let l:new_dots = (l:dots % 3) + 1
      call setbufline(s:chat_buffer, '$', 'Waiting for response' . repeat('.', l:new_dots))
    let s:color_index = (s:color_index + 1) % len(s:colors_gui)
    execute 'highlight CopilotWaiting guifg=' . s:colors_gui[s:color_index] . ' ctermfg=' . s:colors_cterm[s:color_index]
  endif
  return 1
endfunction

function! AsyncRequest(message)
  let l:chat_token = ValidateToken()
  let s:curl_output = []
  let l:url = 'https://api.githubcopilot.com/chat/completions'

  call appendbufline(s:chat_buffer, '$', 'Waiting for response')
  let s:waiting_timer = timer_start(500, {-> UpdateWaitingDots()}, {'repeat': -1})

  " for knowledge bases its just an attachment as the content
  "{'content': '<attachment id="kb:Name">\n#kb:\n</attachment>', 'role': 'user'}
  " for files similar
  let l:messages = [{'content': a:message, 'role': 'user'}]
  let l:data = json_encode({
        \ 'intent': v:false,
        \ 'model': s:default_model,
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

  let job = job_start(l:curl_cmd, {'out_cb': function('HandleCurlOutput'), 'exit_cb': function('HandleCurlClose'), 'err_cb': function('HandleCurlError')})
  return job
endfunction

function! HandleCurlError(channel, msg)
  echom 'handling curl error'
  echom a:msg
endfunction

function! HandleCurlClose(channel, msg)
  call deletebufline(s:chat_buffer, '$')
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

  let l:width = winwidth(0)-2
  let l:separator = ' '
  let l:separator .= repeat('━', l:width)
  call appendbufline(s:chat_buffer, '$', l:separator)
  call appendbufline(s:chat_buffer, '$', split(l:result, "\n"))
  call UserInputSeparator()
endfunction

function! HandleCurlOutput(channel, msg)
  call add(s:curl_output, a:msg)
endfunction

function! AddSelectionToChatBuffer()
  " Save the current register and selection type
  let l:save_reg = @"
  let l:save_regtype = getregtype('"')
  let l:filetype = &filetype

  " Get the visual selection
  normal! gv"xy

  " Get the content of the visual selection
  let l:selection = getreg('x')

  " Restore the original register and selection type
  call setreg('"', l:save_reg, l:save_regtype)
  call appendbufline(s:chat_buffer, '$', '```' . l:filetype)
  call appendbufline(s:chat_buffer, '$', split(l:selection, "\n"))
  call appendbufline(s:chat_buffer, '$', '```')
endfunction

command! CopilotChat call CopilotChat()
command! SubmitChatMessage call SubmitChatMessage()
command! CopilotConfig call ViewConfig()
command! CopilotModels call ViewModels()
command! SelectModel call SelectModel()

nnoremap <leader>cc :CopilotChat<CR>
vnoremap <silent> <leader>a :<C-u>call AddSelectionToChatBuffer()<CR>
