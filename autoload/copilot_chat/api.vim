vim9script
scriptencoding utf-8

import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/buffer.vim' as _buffer
import autoload 'copilot_chat/models.vim' as models

def UserStatsClose(winid: number, key: string): number
  if key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    return 1
  endif

  return 1
enddef

export def GetUsage()
  var device_token_file: string = $'{g:copilot_chat_data_dir}/.device_token'
  var bearer_token = join(readfile(device_token_file), "\n")
  var token_headers = [
    'Accept: application/json',
    'Accept-Encoding: gzip,deflate,br',
    'Content-Type: application/json',
    $'Authorization: token {bearer_token}'
  ]

  var command = HttpCommand('GET', 'https://api.github.com/copilot_internal/user', token_headers, {})
  var output = []
  job_start(command, {
    'out_cb': (channel, msg) => output->add(msg),
    'exit_cb': (job, status) => HandleUserUsageExit(output, status)
  })
enddef

def HandleUserUsageExit(output: list<string>, status: number)
  if status == 0
    var raw_response = join(output, '')
    var response = json_decode(raw_response)
    var display_items = []
    display_items->add('Copilot Plan: ' .. response['copilot_plan'])
    display_items->add('Chat messages: ' .. response['quota_snapshots']['chat']['unlimited'])

    var premium_interactions = response['quota_snapshots']['premium_interactions']
    var total_count = premium_interactions['entitlement']
    var used_count = total_count - premium_interactions['remaining']
    display_items->add('Premium Requests Used: ' .. used_count .. ' / ' .. total_count)
    display_items->add('Quota resets at: ' .. response['quota_reset_date'])

    var options = {
      'border': [1, 1, 1, 1],
      'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
      'borderhighlight': ['DiffAdd'],
      'highlight': 'PopupNormal',
      'padding': [1, 1, 1, 1],
      'pos': 'center',
      'minwidth': 50,
      'title': 'Copilot User Info',
      'filter': UserStatsClose,
      'close': 'button'
    }
    popup_create(display_items, options)
  endif
enddef

var curl_output: list<string> = []

export def AsyncRequest(messages: list<any>, file_list: list<any>): job
  curl_output = []

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

  var model: string = models.Resolve()
  var endpoint: string = models.Endpoint(model)
  var url: string = 'https://api.githubcopilot.com' .. endpoint
  var data: string

  if endpoint ==# '/responses'
    # The /responses API takes the conversation as 'input' and rejects the
    # sampling options accepted by /chat/completions.
    data = json_encode({
      'model': model,
      'input': messages,
      'stream': true
    })
  else
    data = json_encode({
      'intent': false,
      'model': model,
      'temperature': 0,
      'top_p': 1,
      'n': 1,
      'stream': true,
      'messages': messages
    })
  endif

  var tmpfile: string = tempname()
  writefile([data], tmpfile)

  var curl_cmd: list<string> = [
    'curl',
    '-N',
    '--ssl-no-revoke',
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
      var payload: any
      try
        payload = json_decode(strcharpart(line, 6))
      catch
        continue
      endtry

      if type(payload) != v:t_dict
        continue
      endif

      # /chat/completions streams choices[].delta.content
      if has_key(payload, 'choices')
        && len(payload.choices) > 0
        && has_key(payload.choices[0], 'delta')
        && has_key(payload.choices[0].delta, 'content')

        var content = payload.choices[0].delta.content
        if type(content) != type(v:null)
          result ..= content
        endif

      # /responses streams response.output_text.delta events
      elseif get(payload, 'type', '') ==# 'response.output_text.delta'
        var delta = get(payload, 'delta', '')
        if type(delta) == v:t_string
          result ..= delta
        endif
      endif

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

export def FetchModels()
  if exists('g:copilot_chat_test_mode')
    return
  endif

  var chat_headers = [
    $'Authorization: Bearer {g:copilot_chat_token}',
    'Editor-Version: vscode/1.107.0',
    'Editor-Plugin-Version: copilot-chat/0.36.2025121601',
    'x-github-api-version: 2025-10-01'
  ]

  var command = HttpCommand('GET', 'https://api.githubcopilot.com/models', chat_headers, {})
  var output = []
  job_start(command, {
    'out_cb': (channel, msg) => output->add(msg),
    'exit_cb': (job, status) => HandleFetchModelsExit(output, status)
  })
enddef

def HandleFetchModelsExit(output: list<string>, status: number)
  if status != 0
    g:copilot_chat_available_models = []
    g:copilot_chat_model_multipliers = {}
    g:copilot_chat_model_endpoints = {}
    auth.GetTokens()
    return
  endif

  try
    var response = join(output, '')
    var model_list: list<string> = []
    var model_multipliers: dict<any> = {}
    var model_endpoints: dict<any> = {}
    var json_response = json_decode(response)
    var items: list<any> = []

    if type(json_response) == v:t_dict && has_key(json_response, 'data')
      items = json_response.data
    elseif type(json_response) == v:t_list
      items = json_response
    endif

    for item in items
      if type(item) != v:t_dict || !has_key(item, 'id')
        continue
      endif

      if get(item, 'model_picker_enabled', true) == false
        continue
      endif

      # Keep models served by an endpoint we know how to drive
      var endpoints: list<any> = get(item, 'supported_endpoints', [])
      if !empty(endpoints)
          && index(endpoints, '/chat/completions') == -1
          && index(endpoints, '/responses') == -1
        continue
      endif

      model_list->add(item.id)
      model_multipliers[item.id] = get(get(item, 'billing', {}), 'multiplier', 1)
      model_endpoints[item.id] = endpoints
    endfor

    g:copilot_chat_available_models = model_list
    g:copilot_chat_model_multipliers = model_multipliers
    g:copilot_chat_model_endpoints = model_endpoints
    if empty(model_list)
      echom 'No Copilot models returned from the API'
    endif
  catch
    g:copilot_chat_available_models = []
    g:copilot_chat_model_multipliers = {}
    g:copilot_chat_model_endpoints = {}
    echom 'Failed to load Copilot models'
  endtry
enddef

export def HttpCommand(method: string, url: string, headers: list<any>, body: any): any
  # curl is already required for the streaming chat request, so use it on every
  # platform: spawning PowerShell/Invoke-WebRequest costs several seconds and
  # mangles header values that contain '=' or ';'.
  var command: list<string> = ['curl', '-s', '-X', method, '--compressed']

  if has('win32')
    # Schannel cannot always reach the CRL distribution point
    command->add('--ssl-no-revoke')
  endif

  for header in headers
    command->add('-H')
    command->add(header)
  endfor

  if method !=# 'GET'
    command->add('-d')
    command->add(json_encode(body))
  endif

  command->add(url)

  return command
enddef
