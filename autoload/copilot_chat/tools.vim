let g:mcp_tools = []
let s:sse_jobs = {}
let s:mcp_messages = []

function! s:is_valid_json(str)
  try
    call json_decode(a:str)
    return 1
  catch
    return 0
  endtry
endfunction

"XXX: cleanup later
function! s:base_url(url) abort
  return substitute(a:url, '\(https\?://[^/]\+\).*', '\1', '')
endfunction

function! copilot_chat#tools#mcp_function_call(function_name, arguments) abort
    let cleaned_args = {}
    if a:arguments != ""
      let cleaned_args = json_decode(a:arguments)
    endif

    let l:request_id = localtime()
    let l:request = {
        \ 'jsonrpc': '2.0',
        \ 'id': l:request_id,
        \ 'method': 'tools/call',
        \ 'params': {"name": a:function_name, "arguments": cleaned_args}
    \ }
    "let l:function_url = copilot_chat#tools#find_by_name(a:function_name).url
    let server = copilot_chat#tools#find_server_by_tool_name(a:function_name)
    if has_key(server, 'command')
      call copilot_chat#log#write("COMMAND MCP FUNCTION CALL")
    elseif has_key(server, "type")
      if server.type == "sse"
        let endpoint = s:base_url(server['url']) . server['endpoint']
        let cleaned_endpoint = substitute(endpoint, '?', '', '')
        let tools_response = copilot_chat#http('POST', cleaned_endpoint, ['Content-Type: application/json'], l:request)[0]
        call copilot_chat#log#write("MCP FUNCTION CALL")
        call copilot_chat#log#write(cleaned_endpoint)
      else
        let tools_response = copilot_chat#tools#mcp_http_request('POST', server, l:request)[0]
        call s:HandleMCPMessage(json_decode(tools_response))
      endif
    endif

    return tools_response
endfunction

function! copilot_chat#tools#fetch() abort
  return g:mcp_tools
endfunction

function! s:HandleMCPMessage(message)
    " Handle tools/list response
    if has_key(a:message, 'result') && has_key(a:message.result, 'tools')
        call copilot_chat#log#write("🛠️  Available Tools:")
        call copilot_chat#log#write(a:message['id'])

        let l:tools = a:message.result.tools
        call copilot_chat#tools#add_tools_to_mcp_server(a:message.id, l:tools)
        call copilot_chat#tools#update_mcp_servers_by_id(a:message.id, 'status', 'success')

        "call s:AppendToBuffer(a:bufnr, [""])
    elseif has_key(a:message, 'result') && has_key(a:message.result, 'content')
      let l:mcp_output = a:message.result.content[0].text
      call copilot_chat#log#write("inside the mssage process")
      call copilot_chat#log#write(l:mcp_output)
      call copilot_chat#buffer#append_message('MCP FUNCTION RESPONSE: ' . l:mcp_output)
      call add(g:buffer_messages[g:copilot_chat_active_buffer], {'role': 'tool', 'content': l:mcp_output, 'tool_call_id': g:last_tool.call_id})
      call add(g:buffer_messages[g:copilot_chat_active_buffer], {'role': 'user', 'content': 'Above is the result of calling one or more tools. The user cannot see the results, so you should explain them to the user if referencing them in your answer. Continue from where you left off if needed without repeating yourself.'})
      call copilot_chat#log#write("added to buffer")
      call copilot_chat#api#async_request(g:buffer_messages[g:copilot_chat_active_buffer], [])
      "call add(l:messages, {'role': 'tool', 'content': mcp_output, 'tool_call_id': l:function_request['id']})
    endif

    " Handle errors
    if has_key(a:message, 'error')
        call copilot_chat#tools#update_mcp_servers_by_id(a:message.id, 'status', 'failed')
        "call s:AppendToBuffer(a:bufnr, [
            "\ "❌ MCP Error: " . a:message.error.message . " (Code: " . a:message.error.code . ")"
        "\ ])
    endif
endfunction

function! s:build_curl_sse_command(url)
  let l:cmd = ['curl', '-N', '-s']
  let l:cmd += ['-H', 'Accept: text/event-stream']
  let l:cmd += ['-H', 'Cache-Control: no-cache']
  let l:cmd += ['-H', 'Connection: keep-alive']
  let l:cmd += [a:url]
  return l:cmd
endfunction

" XXX: bug here with registering tools
function! s:handle_stdio_response(data, server_id) abort
  let function_call = a:data.id
  call copilot_chat#log#write("tools magica" . a:server_id)
  call copilot_chat#log#write("tools magicaff" . json_encode(a:data))
  if has_key(a:data.result, 'tools')
    call copilot_chat#tools#add_tools_to_mcp_server(a:server_id, a:data.result.tools)
    call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'success')
  endif
endfunction

function! s:on_stdio_output(server_id, job, data)
  "let l:lines = split(a:data, '\n', 1)
  call copilot_chat#log#write("on_stdio_ouput" . a:data)
  call copilot_chat#log#write("on_stdio_ouput" . a:server_id)
  try
    call s:handle_stdio_response(json_decode(a:data), a:server_id)
  catch
    echom "Error parsing MCP response: " . v:exception
  endtry
endfunction

function! s:on_stdio_error(server_id, job, data)
  call copilot_chat#log#write("❌ Stdio Error: " . a:data)
  call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'failed')
endfunction

function! s:on_stdio_exit(server_id, data, exit_status)
  call copilot_chat#log#write("🔌 stdio connection closed (exit: " . a:exit_status . ")")
  if a:exit_status != 0
    call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'failed')
  endif
endfunction

function! s:send_request(request, job) abort
  let json_str = json_encode(a:request) . "\n"
  call ch_sendraw(a:job, json_str)
endfunction

function! s:send_initialize_request(server_id, job) abort
  let request = {
        \ 'jsonrpc': '2.0',
        \ 'id': a:server_id,
        \ 'method': 'initialize',
        \ 'params': {
        \   'protocolVersion': '2024-11-05',
        \   'capabilities': {
        \     'roots': {'listChanged': v:true},
        \     'sampling': {}
        \   },
        \   'clientInfo': {
        \     'name': 'vim-mcp-client',
        \     'version': '1.0.0'
        \   }
        \ }
        \ }
  call s:send_request(request, a:job)

  "make tools_request
  let tool_request = {
        \ 'jsonrpc': '2.0',
        \ 'id': a:server_id,
        \ 'method': 'tools/list',
        \ 'params': {}
        \ }
  call s:send_request(tool_request, a:job)
endfunction

function! s:on_sse_output(extra1, job, data)
  "let l:url = a:context.url
  let l:lines = split(a:data, '\n', 1)
  "call copilot_chat#log#write("on_sse_ouput" . a:data)
  call copilot_chat#log#write("on_sse_ouput" . a:extra1)
  "call copilot_chat#log#write("on_sse_ouput" . a:job)
  for l:line in l:lines
    if !empty(l:line)
      call s:ProcessSSELine(l:line, a:extra1)
    endif
  endfor
endfunction

function! s:on_sse_error(server_id, job, data)
  call copilot_chat#log#write("❌ SSE Error: " . a:data)
  call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'failed')
endfunction

"function! s:on_sse_exit(job, exit_status)
function! s:on_sse_exit(extra1, job, exit_status)
  call copilot_chat#log#write("🔌 SSE connection closed (exit: " . a:exit_status . ")" . a:extra1)
  " TODO: this should be handled for all types of MCP Servers
  if has_key(s:sse_jobs, a:extra1)
    call copilot_chat#log#write("unletting the job")
    unlet s:sse_jobs[a:extra1]
  endif
endfunction

function! copilot_chat#tools#find_server_by(key, value) abort
  for server in g:copilot_chat_mcp_servers
    if server[a:key] ==# a:value
      return server
    endif
  endfor
  return {}
endfunction

function! copilot_chat#tools#find_server_by_url(url) abort
  for server in g:mcp_servers
    if server.url ==# a:url
      return server
    endif
  endfor
  return {}
endfunction

function! copilot_chat#tools#add_tools_to_mcp_server(server_id, tools) abort
  call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'tools', a:tools)
  for l:i in range(len(a:tools))
      let l:tool = a:tools[l:i]
      let ff = {"type": "function", "function": {"name": l:tool['name'], 'description': get(l:tool, 'description', 'No description'), 'parameters': {"type": "object", "properties":  {}, "required": []}}}
      call add(g:mcp_tools, ff)

      " Show parameters if available
      if has_key(l:tool, 'inputSchema') && has_key(l:tool.inputSchema, 'properties')
          let l:required = get(l:tool.inputSchema, 'required', [])
          "call s:AppendToBuffer(a:bufnr, ["     Parameters:"])

          for l:prop_name in keys(l:tool.inputSchema.properties)
              let l:prop = l:tool.inputSchema.properties[l:prop_name]
              let l:req_marker = index(l:required, l:prop_name) >= 0 ? ' (required)' : ''
              let l:type_info = get(l:prop, 'type', 'unknown')
              "call s:AppendToBuffer(a:bufnr, [
                  \ "       - " . l:prop_name . ": " . l:type_info . l:req_marker
              \ ])
          endfor
      endif
  endfor
endfunction

"function! copilot_chat#tools#update_mcp_servers_by_id(id, tool_response) abort
function! copilot_chat#tools#update_mcp_servers_by_id(id, key, value) abort
  for server in g:copilot_chat_mcp_servers
    call copilot_chat#log#write('checking id ' . server.id)
    call copilot_chat#log#write('checking id ' . a:id)
    if server.id == a:id
      call copilot_chat#log#write('found a match and updating')
      let server[a:key] = a:value
      "let server.tools = a:tool_response
      return server
    endif
  endfor

  return {}
endfunction

function! copilot_chat#tools#update_server_tools_by_url(url, tool_response) abort
  for server in g:copilot_chat_mcp_servers
    if has_key(server, "url") && server.url ==# a:url
      call copilot_chat#log#write('found a match and updating')
      let server.tools = a:tool_response
      return server
    endif
  endfor

  return {}
endfunction

function! copilot_chat#tools#find_server_by_tool_name(tool_name) abort
  let l:m = {}
  for server in g:copilot_chat_mcp_servers
    " iterate over the tools in each server and return if we find a match
    if has_key(server, "tools")
      for tool in server.tools
        if tool.name == a:tool_name
          let l:m = server
          "return server
        endif
      endfor
    endif
  endfor

  return l:m
endfunction

function! s:send_tools_list_request(arg1, timer_id) abort
    "let l:request_id = localtime()
    "let l:request_id = '20'
    let l:request_id = a:arg1
    call copilot_chat#log#write("checking request id " . a:arg1)
    call copilot_chat#log#write("checking request id " . a:timer_id)
    " Create JSON-RPC request for tools/list
    let l:request = {
        \ 'jsonrpc': '2.0',
        \ 'id': l:request_id,
        \ 'method': 'tools/list',
        \ 'params': {}
    \ }

    call copilot_chat#log#write(json_encode(l:request))
    let tools_response = copilot_chat#http('POST', 'http://localhost:3000/mcp/messages', ['Content-Type: application/json'], l:request)[0]
    call copilot_chat#log#write('toools')
    call copilot_chat#log#write(tools_response)
    "call copilot_chat#tools#update_server_tools_by_url(a:url, tools_response)
    return tools_response
endfunction

function! s:ProcessSSELine(line, details)
    let l:line = trim(a:line)
    if empty(l:line)
        return
    endif

    let l:timestamp = strftime("[%H:%M:%S]")

    if l:line =~# '^data:\s*'
        let l:data = substitute(l:line, '^data:\s*', '', '')
        call copilot_chat#log#write(l:timestamp . " 📨 Data: " . l:data)

        " Try to parse as JSON for MCP messages
        try
            let l:json = json_decode(l:data)
            call s:HandleMCPMessage(l:json)
        catch
          if l:data =~# '^\/'
            call copilot_chat#log#write(l:timestamp . " 🐕 ruhroh: " . l:data)
            call copilot_chat#log#write(l:timestamp . " 🐕 ruhroh: " . a:details)
            " set the endpoint for the current value
            call copilot_chat#tools#update_mcp_servers_by_id(a:details, 'endpoint', l:data)
          endif
            " Not JSON, ignore
        endtry

    elseif l:line =~# '^event:\s*'
        let l:event = substitute(l:line, '^event:\s*', '', '')
        call copilot_chat#log#write(l:timestamp . " 🏷️  Event: " . l:event)

    elseif l:line =~# '^id:\s*'
        let l:id = substitute(l:line, '^id:\s*', '', '')
        call copilot_chat#log#write(l:timestamp . " 🆔 ID: " . l:id)

    elseif l:line =~# '^retry:\s*'
        let l:retry = substitute(l:line, '^retry:\s*', '', '')
        call copilot_chat#log#write(l:timestamp . " 🔄 Retry: " . l:retry . "ms")

    else
        call copilot_chat#log#write(l:timestamp . " 📝 Raw: " . l:line)
    endif
endfunction

"function! s:http_tools_list(details) abort
function! s:http_tools_list(server_id, det) abort
  "let details = json_decode(a:details)
  let server = copilot_chat#tools#find_server_by('id', a:server_id)
  let tool_request = {
        \ 'jsonrpc': '2.0',
        \ 'id': a:server_id,
        \ 'method': 'tools/list',
        \ 'params': {}
        \ }
  try
    let tool_response = copilot_chat#tools#mcp_http_request('POST', server, tool_request)[0]
    "let tool_response = copilot_chat#http('POST', server.url, ['Content-Type: application/json', 'Accept: application/json,text/event-stream'], tool_request)[0]
    call copilot_chat#log#write("Tool response " .tool_response)
    call copilot_chat#tools#add_tools_to_mcp_server(a:server_id, json_decode(tool_response).result.tools)
    call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'success')
  catch
    call copilot_chat#tools#update_mcp_servers_by_id(a:server_id, 'status', 'failed')
  endtry
endfunction

function! copilot_chat#tools#mcp_http_request(method, details, request_body, session_id=v:null) abort
  let request_headers = ['Content-Type: application/json', 'Accept: application/json,text/event-stream']
  "if a:session_id != v:null
    "call add(request_headers, 'mcp-session-id: ' . a:session_id)
  "endif
  if has_key(a:details, 'session-id')
    call add(request_headers, 'mcp-session-id: ' . a:details['session-id'])
  endif
  if has_key(a:details, 'headers')
    for header_key in keys(a:details.headers)
      call add(request_headers, header_key . ': ' . a:details.headers[header_key])
    endfor
  endif
  return copilot_chat#http(a:method, a:details.url, request_headers, a:request_body)
endfunction

function! s:start_http_server(details) abort
  "let l:cmd = s:build_curl_http_command(a:details.url)
  call copilot_chat#log#write("Starting HTTP Request" . a:details.url)
  let request = {
        \ 'jsonrpc': '2.0',
        \ 'id': a:details.id,
        \ 'method': 'initialize',
        \ 'params': {
        \   'protocolVersion': '2024-11-05',
        \   'capabilities': {
        \     'roots': {'listChanged': v:true},
        \     'sampling': {}
        \   },
        \   'clientInfo': {
        \     'name': 'vim-mcp-client',
        \     'version': '1.0.0'
        \   }
        \ }
        \ }
  try
    "let init_request = copilot_chat#http('POST', a:details.url, request_headers, request)[0]
    let init_request = copilot_chat#tools#mcp_http_request('POST', a:details, request)
    if has_key(init_request[1], 'mcp-session-id')

      let session_id = init_request[1]['mcp-session-id']
      let g:copilot_chat_mcp_servers[a:details.id - 1]['session-id'] = session_id

      let post_init_request = {
            \ "jsonrpc": "2.0",
            \ "method": "notifications/initialized"
            \ }
      let ready_response = copilot_chat#tools#mcp_http_request('POST', a:details, post_init_request, session_id)[0]
      call copilot_chat#log#write("ready response" . ready_response)
      call timer_start(2000, function('s:http_tools_list', [a:details.id]))
    else
      echom "failed to init mcp server"
      call copilot_chat#tools#update_mcp_servers_by_id(a:details.id, 'status', 'failed')
    endif
  catch
    call copilot_chat#tools#update_mcp_servers_by_id(a:details.id, 'status', 'failed')
  endtry

  return 1
endfunction

function! s:start_sse_job(details) abort
  let l:cmd = s:build_curl_sse_command(a:details['url'])
  let l:job_options = {
        \ 'out_cb': function('s:on_sse_output', [a:details['id']]),
        \ 'err_cb': function('s:on_sse_error', [a:details['id']]),
        \ 'exit_cb': function('s:on_sse_exit', [a:details['id']]),
        \ 'out_mode': 'raw',
        \ 'err_mode': 'raw'
  \ }
  let l:job = job_start(l:cmd, l:job_options)
  call copilot_chat#log#write("Starting the job " . a:details.id)
  call copilot_chat#log#write("Starting the job " . json_encode(a:details))
  call timer_start(2000, function('s:send_tools_list_request', [a:details.id]))
  return l:job
endfunction

function! s:start_command_job(details) abort
  let cmd = [a:details.cmd]
  let cmd += a:details.args
  let job_options = {
        \ 'out_cb': function('s:on_stdio_output', [a:details['id']]),
        \ 'err_cb': function('s:on_stdio_error', [a:details['id']]),
        \ 'exit_cb': function('s:on_stdio_exit', [a:details['id']]),
        \ 'out_mode': 'raw',
        \ 'err_mode': 'raw'
  \ }
  let job = job_start(cmd, job_options)
  sleep 100m
  call s:send_initialize_request(a:details['id'], job)
  return job
endfunction

function! copilot_chat#tools#load_mcp_servers(server_list)
  " TODO: actual format for finding /messages endpoint is not this simple
  " use the ruby example I have to do this same work

  let l:i = 1
  for mcp_server_name in keys(a:server_list)
    let details = a:server_list[mcp_server_name]
    call copilot_chat#log#write("loading" . mcp_server_name . " : " . l:i)
    if has_key(details, 'type')
      let obj = {'name': mcp_server_name, 'url': details.url, 'id': l:i, 'status': 'pending'}
      " add headers if present in config
      if has_key(details, 'headers')
        let obj['headers'] = details.headers
      endif

      if details.type == "sse"
        " add to the global list for reference
        let obj['type'] = 'sse'
        let job_id = s:start_sse_job(obj)
        let obj['job_id'] = job_id
        call add(g:copilot_chat_mcp_servers, obj)
      elseif details.type == "http"
        " add to the global list for reference
        let obj['type'] = 'http'
        call add(g:copilot_chat_mcp_servers, obj)
        let job_id = s:start_http_server(obj)
      endif
      " for now just sse
      "
    else
      let obj = {'name': mcp_server_name, 'id': l:i, 'cmd': details.command, 'args': details.args, 'status': 'pending'}
      let job_id = s:start_command_job(obj)
      call add(g:copilot_chat_mcp_servers, obj)
    endif

    let l:i += 1
  endfor
endfunction
