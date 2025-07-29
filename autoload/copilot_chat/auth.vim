let s:device_token_file = g:copilot_chat_data_dir .  '/.device_token'
let s:chat_token_file = g:copilot_chat_data_dir . '/.chat_token'

function! copilot_chat#auth#verify_signin() abort
  let l:chat_token = copilot_chat#auth#get_chat_token(v:false)
  try
    call copilot_chat#api#fetch_models(l:chat_token)
  catch
    let l:chat_token = copilot_chat#auth#get_chat_token(v:true)
  endtry
  return l:chat_token
endfunction

function! copilot_chat#auth#get_chat_token(fetch_new) abort
  if filereadable(s:chat_token_file) && a:fetch_new == v:false
    return join(readfile(s:chat_token_file), "\n")
  else
    "call copilot_chat#api#get_token()
    call copilot_chat#config#create_data_dir()
    let l:bearer_token = copilot_chat#auth#get_bearer_token()
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
    let l:response = copilot_chat#http('GET', l:token_url, l:token_headers, l:token_data)[0]
    let l:json_response = json_decode(l:response)
    let l:chat_token = l:json_response.token
    call writefile([l:chat_token], s:chat_token_file)

    return l:chat_token
  endif
endfunction

function! copilot_chat#auth#get_bearer_token() abort
  if filereadable(s:device_token_file)
    return join(readfile(s:device_token_file), "\n")
  else
    let l:response = copilot_chat#auth#get_device_token()
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
      let l:token_headers = [
        \ 'Accept: application/json',
        \ 'User-Agent: GithubCopilot/1.155.0',
        \ 'Accept-Encoding: gzip,deflate,br',
        \ 'Editor-Plugin-Version: copilot.vim/1.16.0',
        \ 'Editor-Version: vim/9.0.1',
        \ 'Content-Type: application/json',
        \ ]

    let l:access_token_response = copilot_chat#http('POST', l:token_poll_url, l:token_headers, l:token_poll_data)[0]
    let l:json_response = json_decode(l:access_token_response)
    let l:bearer_token = l:json_response.access_token
    call writefile([l:bearer_token], s:device_token_file)

    return l:bearer_token
  endif
endfunction

function! copilot_chat#auth#get_device_token() abort
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

  return copilot_chat#http('POST', l:token_url, l:headers, l:data)[0]
endfunction

" vim:set ft=vim sw=2 sts=2 et:
