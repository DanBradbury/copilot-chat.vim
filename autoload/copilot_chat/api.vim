vim9script
scriptencoding utf-8

import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/buffer.vim' as _buffer
import autoload 'copilot_chat/models.vim' as models
import autoload 'copilot_chat/tools.vim' as tools

var curl_output: list<string> = []

export def AgentRequest(message: string): void
  var chat_token: string = auth.VerifySignin()
  var user_obj = {
    "role": "user",
    'content': [{
      'type': 'input_text',
      'text': '<userRequest>\nUpdate the CONTRIBUTING.md file to include more emojis throughout the file\n</userRequest>'
    }]
  }
  var messages = [user_obj]
  var url: string = 'https://api.individual.githubcopilot.com/responses'
  var data: string = json_encode({
    'model': models.Current(),
    'stream': true,
    'tools': tools.List(),
    'input': messages
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
    '-H', 'Authorization: Bearer ' .. chat_token,
    '-H', 'Editor-Version: vscode/1.80.1',
    '-d',
    $'@{tmpfile}',
    url
  ]

  var job: job = job_start(curl_cmd, {
     'out_cb': function('HandleAgentJobOutput'),
     'exit_cb': function('HandleAgentJobClose'),
     'err_cb': function('HandleAgentJobError')
     })
enddef

export def AsyncRequest(messages: list<any>, file_list: list<any>): job
  var chat_token: string = auth.VerifySignin()
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
    '-H', 'Authorization: Bearer ' .. chat_token,
    '-H', 'Editor-Version: vscode/1.80.1',
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

def HandleAgentJobOutput(channel: any, msg: any): void
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

def HandleAgentJobClose(channel: any, msg: any)
  echom 'job finished'
  var a = 1
  for line in curl_output
    if line =~? '^data: {'
      var json_completion = json_decode(strcharpart(line, 6))
      try
        if json_completion['response']['output'] != v:null
          for outcome in json_completion['response']['output']
            if outcome['type'] == 'function_call'
              # call the function here
              echom 'calling function'
              echom outcome
              _buffer.AppendMessage(line)
              tools.InvokeTool(outcome)
            elseif outcome['type'] == 'message'
              for m in outcome['content']
                _buffer.AppendMessage(m['text'])
              endfor
            endif
          endfor
        endif
      catch
        a = 2
      endtry
    endif
  endfor
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

def HandleAgentJobError(channel: any, msg: list<any>)
  echom msg
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

export def FetchModels(chat_token: string): list<string>
  if exists('g:copilot_chat_test_mode')
    return ['gpt-o4']
  endif

  var chat_headers = [
    'Content-Type: application/json',
    $'Authorization: Bearer {chat_token}',
    'Editor-Version: vscode/1.80.1'
  ]

  var response = Http('GET', 'https://api.githubcopilot.com/models', chat_headers, {})
  var model_list = []
  var json_response = json_decode(response)
  for item in json_response.data
    if has_key(item, 'id')
      add(model_list, item.id)
    endif
  endfor
  return model_list
enddef

export def Http(method: string, url: string, headers: list<any>, body: any): string
  var response = ''
  if has('win32')
    var ps_cmd = 'powershell -Command "'
    ps_cmd ..= '$headers = @{'
    for header in headers
      var parts = split(header, ': ')
      var key = parts[0]
      var value = parts[1]
      ps_cmd ..= "'" .. key .. "'='" .. value .. "';"
    endfor
    ps_cmd ..= '};'
    if method !=# 'GET'
      ps_cmd ..= '$body = ConvertTo-Json @{'
      for obj in keys(body)
        ps_cmd ..= obj .. "='" .. body[obj] .. "';"
      endfor
      ps_cmd ..= '};'
    endif
    ps_cmd ..= "Invoke-WebRequest -Uri '" .. url .. "' -Method " .. method .. " -Headers $headers -Body $body -ContentType 'application/json' | Select-Object -ExpandProperty Content"
    ps_cmd ..= '"'
    response = system(ps_cmd)
  else
    var token_data = json_encode(body)

    var curl_cmd = 'curl -s -X ' .. method .. ' --compressed '
    for header in headers
      curl_cmd ..= '-H "' .. header .. '" '
    endfor
    curl_cmd ..= "-d '" .. token_data .. "' " .. url

    response = system(curl_cmd)
    if v:shell_error != 0
      echom 'Error: ' .. v:shell_error
      return ''
    endif
  endif
  return response
enddef
