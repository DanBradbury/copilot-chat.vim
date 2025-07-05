let g:mcp_tools = []
let s:sse_jobs = {}
let s:mcp_messages = []

"XXX: cleanup later
function! s:base_url(url) abort
  return substitute(a:url, '\(https\?://[^/]\+\).*', '\1', '')
endfunction

function! copilot_chat#tools#mcp_function_call(function_name) abort
    let l:request_id = localtime()
    let l:request = {
        \ 'jsonrpc': '2.0',
        \ 'id': l:request_id,
        \ 'method': 'tools/call',
        \ 'params': {"name": a:function_name, "arguments": {}}
    \ }
    "let l:function_url = copilot_chat#tools#find_by_name(a:function_name).url
    let server = copilot_chat#tools#find_server_by_tool_name(a:function_name)
    let endpoint = s:base_url(server['url']) . server['endpoint']
    let cleaned_endpoint = substitute(endpoint, '?', '', '')
    call copilot_chat#log#write(cleaned_endpoint)

    let tools_response = copilot_chat#http('POST', cleaned_endpoint, ['Content-Type: application/json'], l:request)
    call copilot_chat#log#write("MCP FUNCTION CALL")
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
        call copilot_chat#tools#update_mcp_servers_by_id(a:message.id, 'tools', l:tools)
        for l:i in range(len(l:tools))
            let l:tool = l:tools[l:i]
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

"function! s:on_sse_output(job, data)
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

function! s:on_sse_error(job, data)
  call copilot_chat#log#write("❌ SSE Error: " . a:data)
endfunction

function! s:on_sse_exit(job, exit_status)
  call copilot_chat#log#write("🔌 SSE connection closed (exit: " . a:exit_status . ")")
  if has_key(s:sse_jobs, a:bufnr)
    unlet s:sse_jobs[a:bufnr]
  endif
endfunction

function! copilot_chat#tools#find_server_by_url(url) abort
  for server in g:mcp_servers
    if server.url ==# a:url
      return server
    endif
  endfor
  return {}
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
    if server.url ==# a:url
      call copilot_chat#log#write('found a match and updating')
      let server.tools = a:tool_response
      return server
    endif
  endfor

  return {}
endfunction

function! copilot_chat#tools#find_server_by_tool_name(tool_name) abort
  for server in g:copilot_chat_mcp_servers
    " iterate over the tools in each server and return if we find a match
    for tool in server.tools
      if tool.name ==# a:tool_name
        return server
      endif
    endfor
  endfor

  return {}
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
    let tools_response = copilot_chat#http('POST', 'http://localhost:3000/mcp/messages', ['Content-Type: application/json'], l:request)
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

function! s:start_sse_job(details) abort
  let l:cmd = s:build_curl_sse_command(a:details['url'])
  let url = a:details['id']
  let l:job_options = {
        \ 'out_cb': function('s:on_sse_output', [url]),
        \ 'err_cb': function('s:on_sse_error'),
        \ 'exit_cb': function('s:on_sse_exit'),
        \ 'out_mode': 'raw',
        \ 'err_mode': 'raw'
  \ }
  let l:job = job_start(l:cmd, l:job_options)
  call copilot_chat#log#write("Starting the job " . a:details.id)
  call copilot_chat#log#write("Starting the job " . json_encode(a:details))
  call timer_start(2000, function('s:send_tools_list_request', [a:details.id]))
  return l:job
endfunction

function! copilot_chat#tools#load_mcp_servers(server_list)
  " TODO: actual format for finding /messages endpoint is not this simple
  " use the ruby example I have to do this same work

  let l:i = 1
  for mcp_server_name in keys(a:server_list)
    call copilot_chat#log#write("TESTING SSE Connection " . l:i)
    let details = a:server_list[mcp_server_name]
    let url = details['url']
    " add to the global list for reference
    let obj = {'name': mcp_server_name, 'url': url, 'id': l:i}
    let job_id = s:start_sse_job(obj)
    let obj['job_id'] = job_id
    call add(g:copilot_chat_mcp_servers, obj)
    "let l:i += 1
  endfor
endfunction
