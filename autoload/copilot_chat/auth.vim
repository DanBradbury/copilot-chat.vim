vim9script

import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/config.vim' as config

var device_token_file: string = $'{g:copilot_chat_data_dir}/.device_token'
var chat_token_file: string = $'{g:copilot_chat_data_dir}/.chat_token'

export def VerifySignin(): void
  if exists('g:copilot_chat_test_mode')
    return
  endif

  GetTokens()
enddef

def TokenHasExpired(): bool
  return localtime() > TokenExpiryEpoch(g:copilot_chat_token)
enddef

def TokenExpiryEpoch(chat_token: string): number
  try
    var expiry_epoch = split(split(chat_token, ';')[1], '=')[1]
    return str2nr(expiry_epoch)
  catch
    return 0
  endtry
enddef

def ScheduleTokenRefresh(): void
  var expiry_epoch = TokenExpiryEpoch(g:copilot_chat_token)
  var margin = 60
  var delay_ms = (expiry_epoch - localtime() - margin) * 1000
  timer_start(delay_ms, (_) => GetAccessToken())
enddef

export def GetTokens()
  if filereadable(chat_token_file)
    g:copilot_chat_token = join(readfile(chat_token_file), "\n")
    if TokenHasExpired()
      GetAccessToken()
    else
      ScheduleTokenRefresh()
      api.FetchModels()
    endif
  else
    config.CreateDataDir()
    if filereadable(device_token_file)
      GetAccessToken()
    else
      var token_url = 'https://github.com/login/device/code'
      var headers = [
        'Accept: application/json',
        'Accept-Encoding: gzip, deflate, br',
        'Content-Type: application/json',
      ]
      var data = {
        'client_id': 'Iv1.b507a08c87ecfe98',
        'scope': 'read: user'
      }
      var command = api.HttpCommand('POST', token_url, headers, data)
      job_start(command, {'out_cb': function('HandleDeviceToken')})
    endif
  endif
enddef

def GetAccessToken()
  var bearer_token = join(readfile(device_token_file), "\n")
  var token_url = 'https://api.github.com/copilot_internal/v2/token'
  var token_headers = [
    'Accept: application/json',
    'Accept-Encoding: gzip,deflate,br',
    'Content-Type: application/json',
    $'Authorization: token {bearer_token}'
  ]
  var token_data = {
    'client_id': 'Iv1.b507a08c87ecfe98',
    'scope': 'read:user'
  }
  var output = []
  var command = api.HttpCommand('GET', token_url, token_headers, token_data)
  job_start(command, {
    'out_cb': (channel, msg) => output->add(msg),
    'exit_cb': (job, status) => HandleGetTokenExit(output, status)
  })
enddef

def HandleGetTokenExit(lines: list<string>, status: number)
  try
    var json_response = json_decode(join(lines, ''))
    var chat_token = json_response.token
    writefile([chat_token], chat_token_file)
    g:copilot_chat_token = chat_token
    ScheduleTokenRefresh()
    api.FetchModels()
  catch
    # get token failed
  endtry
enddef

def HandleDeviceToken(channel: any, response: any)
  var json_response = json_decode(response)
  var device_code = json_response.device_code
  var user_code = json_response.user_code
  var verification_uri = json_response.verification_uri

  CopyToClipboard(user_code)
  OpenUrl(verification_uri)
  input($"Please go to {verification_uri} and paste the code (added to your clipboard already): {user_code}\nPress Enter to continue when completed...\n")

  var token_poll_url = 'https://github.com/login/oauth/access_token'
  var token_poll_data = {
    'client_id': 'Iv1.b507a08c87ecfe98',
    'device_code': device_code,
    'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'
  }
  var token_headers = [
    'Accept: application/json',
    'Accept-Encoding: gzip,deflate,br',
    'Content-Type: application/json'
  ]

  var access_token_command = api.HttpCommand('POST', token_poll_url, token_headers, token_poll_data)
  job_start(access_token_command, {'out_cb': function('HandleAccessToken')})
enddef

def HandleAccessToken(channel: any, response: string)
  var json_response = json_decode(response)
  var token = json_response.access_token
  writefile([token], device_token_file)
  echom 'Copilot Chat Device Registration Successful!'
  GetAccessToken()
enddef

def OpenUrl(url: string)
  if has('mac') || has('macunix')
    execute '!open ' .. url
  elseif has('win32') || has('win64')
    execute '!start ' .. url
  elseif has('unix')
    execute '!xdg-open ' .. url
  endif
enddef

def CopyToClipboard(text: string)
  if has('clipboard') && has('clipboard_working')
    try
      @+ = text
      @* = text
    catch
      echom 'Registers not available - text not copied'
    endtry
  else
    if has('mac') || has('macunix')
      system('pbcopy', text)
    elseif has('unix')
      system('xclip -selection clipboard', text)
    elseif has('win32') || has('win64')
      system('clip.exe', text)
    else
      echom 'Clipboard not available - text not copied'
    endif
  endif
enddef
