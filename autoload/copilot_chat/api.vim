vim9script
scriptencoding utf-8

import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/buffer.vim' as _buffer
import autoload 'copilot_chat/models.vim' as models

var curl_output: list<string> = []

export def AsyncRequest(messages: list<any>, file_list: list<any>): job
  curl_output = []
  var url: string = 'https://api.githubcopilot.com/chat/completions'

  # for knowledge bases its just an attachment as the content
  # {'content': '<attachment id="kb:Name">\n#kb:\n</attachment>', 'role': 'user'}
  # for files similar
  for file in file_list
    var file_content: list<string> = readfile(file)
    var full_path: string = fnamemodify(file, ': p')
    # TODO: get the filetype instead of just markdown
    var attachment_content: string = '<attachment id="' .. file .. '">\n````markdown\n<!-- filepath: ' .. full_path .. ' -->\n' .. join(file_content, "\n") .. '\n```</attachment>'
    add(messages, {'content': attachment_content, 'role': 'user'})
  endfor

  var data: string = json_encode({
    'intent': false,
    'model': models.Current(),
    'temperature': 0,
    'top_p': 1,
    'n': 1,
    'stream': true,
    'messages': messages
  })

  var tmpfile: string = tempname()
  writefile([data], tmpfile)

  var curl_cmd: list<string> = [
    'curl',
    '-s',
    '-X',
    'POST',
    '-H',
    'Content-Type: application/json',
    '-H', 'Authorization: Bearer ' .. g:copilot_chat_token,
    '-H', 'Editor-Version: vscode/1.107.0',
    '-H', 'Editor-Plugin-Version: copilot-chat/0.36.2025121601',
    '-d',
    $'@{tmpfile}',
    url
  ]

  var job: job = job_start(curl_cmd, {
     'out_cb': function('HandleJobOutput'),
     'exit_cb': function('HandleJobClose'),
     'err_cb': function('HandleJobError')
     })

  _buffer.WaitingForResponse()

  return job
enddef

def HandleJobOutput(channel: any, msg: any): void
  if type(msg) == v:t_list
    for data in msg
      if data =~? '^data: {'
        add(curl_output, data)
      endif
    endfor
  else
    add(curl_output, msg)
  endif
enddef

def HandleJobClose(channel: any, msg: any)
  deletebufline(g:copilot_chat_active_buffer, '$')
  var result = ''
  for line in curl_output
    if line =~? '^data: {'
      var json_completion = json_decode(strcharpart(line, 6))
      try
        var content = json_completion.choices[0].delta.content
        if type(content) != type(v:null)
          result ..= content
        endif
      catch
        result ..= "\n"
      endtry
    elseif line =~? 'error'
      result ..= line
    endif
  endfor

  var response = split(result, "\n")
  var width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
  var separator = ' '
  separator ..= repeat('━', width)
  var response_start = line('$') + 1

  _buffer.AppendMessage(separator)
  _buffer.AppendMessage(response)
  _buffer.AddInputSeparator()

  var wrap_width = width + 2
  var softwrap_lines = 0
  for line in response
    if strwidth(line) > wrap_width
      softwrap_lines += float2nr(ceil(strwidth(line) / wrap_width))
    else
      softwrap_lines += 1
    endif
  endfor

  var total_response_length = softwrap_lines + 2
  var height = winheight(0)
  if total_response_length >= height
    execute 'normal! ' .. response_start .. 'Gzt'
  else
    execute 'normal! G'
  endif
  setcursorcharpos(0, 3)
enddef

def HandleJobError(channel: any, msg: list<any>)
  if type(msg) == v:t_list
    var filtered_errors = filter(copy(msg), '!empty(v:val)')
    if len(filtered_errors) > 0
      echom filtered_errors
    endif
  else
    echom msg
  endif
enddef

export def FetchModels(chat_token: string)
  if exists('g:copilot_chat_test_mode')
    return
  endif

  var chat_headers = [
    $'Authorization: Bearer {chat_token}',
    'Editor-Version: vscode/1.107.0',
    'Editor-Plugin-Version: copilot-chat/0.36.2025121601'
  ]

  var command = HttpCommand('GET', 'https://api.githubcopilot.com/models', chat_headers, {})
  job_start(command, {'err_cb': function('HandleFetchModelsError'), 'out_cb': function('HandleFetchModelsOut')})
enddef

def HandleFetchModelsOut(channel: any, msg: any)
  var model_list = []
  try
    var json_response = json_decode(msg)
    for item in json_response.data
      if has_key(item, 'id')
        add(model_list, item.id)
      endif
    endfor
    g:copilot_chat_available_models = model_list
  catch
    # not valid json yet.. waiting
  endtry
enddef

# if this errors out we should get a new token
def HandleFetchModelsError(channel: any, msg: any)
  auth.GetTokens(true)
enddef

export def HttpCommand(method: string, url: string, headers: list<any>, body: any): string
  var command = ''

  if has('win32')
    command ..= 'powershell -Command "'
    command ..= '$headers = @{'
    for header in headers
      var parts = split(header, ': ')
      var key = parts[0]
      var value = parts[1]
      command ..= "'" .. key .. "'='" .. value .. "';"
    endfor
    command ..= '};'
    if method !=# 'GET'
      command ..= '$body = ConvertTo-Json @{'
      for obj in keys(body)
        command ..= obj .. "='" .. body[obj] .. "';"
      endfor
      command ..= '};'
    endif
    command ..= "Invoke-WebRequest -Uri '" .. url .. "' -Method " .. method .. " -Headers $headers -Body $body -ContentType 'application/json' -UseBasicParsing | Select-Object -ExpandProperty Content"
    command ..= '"'
  else
    var token_data = json_encode(body)

    command ..= 'curl -s -X ' .. method .. ' --compressed '
    for header in headers
      command ..= '-H "' .. header .. '" '
    endfor
    command ..= "-d '" .. token_data .. "' " .. url
  endif

  return command
enddef

