vim9script

import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/config.vim' as config

var device_token_file = $'{g:copilot_chat_data_dir}/.device_token'
var chat_token_file = $'{g:copilot_chat_data_dir}/.chat_token'

export def VerifySignin(): string
  var chat_token = GetChatToken(true)
  try
    api.FetchModels(chat_token)
  catch
    chat_token = GetChatToken(true)
  endtry
  return chat_token
enddef

def GetChatToken(fetch_new: bool): any
  if filereadable(chat_token_file) && fetch_new == false
    return join(readfile(chat_token_file), "\n")
  else
    config.CreateDataDir()
    var bearer_token = GetBearerToken()
    var token_url = 'https://api.github.com/copilot_internal/v2/token'
    var token_headers = [
      'Content-Type: application/json',
      'Editor-Version: vscode/1.80.1',
      $'Authorization: token {bearer_token}'
    ]
    var token_data = {
      'client_id': 'Iv1.b507a08c87ecfe98',
      'scope': 'read:user'
    }
    var response = api.Http('GET', token_url, token_headers, token_data)
    var json_response = json_decode(response)
    try
      var chat_token = json_response.token
      writefile([chat_token], chat_token_file)
      return chat_token
    catch
      echom json_response.message
      return null
    endtry
  endif
enddef

def GetBearerToken(): string
  if filereadable(device_token_file)
    return join(readfile(device_token_file), "\n")
  else
    var response = GetDeviceToken()
    var json_response = json_decode(response)
    var device_code = json_response.device_code
    var user_code = json_response.user_code
    var verification_uri = json_response.verification_uri

    echo 'Please visit ' .. verification_uri .. ' and enter the code: ' .. user_code
    input("Press Enter to continue...\n")

    var token_poll_url = 'https://github.com/login/oauth/access_token'
    var token_poll_data = {
      'client_id': 'Iv1.b507a08c87ecfe98',
      'device_code': device_code,
      'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'
    }
    var token_headers = [
      'Accept: application/json',
      'User-Agent: GithubCopilot/1.155.0',
      'Accept-Encoding: gzip,deflate,br',
      'Editor-Plugin-Version: copilot.vim/1.16.0',
      'Editor-Version: vim/9.0.1',
      'Content-Type: application/json'
    ]

    var access_token_response = api.Http('POST', token_poll_url, token_headers, token_poll_data)
    json_response = json_decode(access_token_response)
    var bearer_token = json_response.access_token
    call writefile([bearer_token], device_token_file)

    return bearer_token
  endif
enddef

def GetDeviceToken(): string
  var token_url = 'https://github.com/login/device/code'
  var headers = [
    'Accept: application/json',
    'User-Agent: GithubCopilot/1.155.0',
    'Accept-Encoding: gzip, deflate, br',
    'Editor-Plugin-Version: copilot.vim/1.16.0',
    'Editor-Version: Neovim/0.6.1',
    'Content-Type: application/json',
  ]
  var data = {
    'client_id': 'Iv1.b507a08c87ecfe98',
    'scope': 'read: user'
  }

  return api.Http('POST', token_url, headers, data)
enddef
