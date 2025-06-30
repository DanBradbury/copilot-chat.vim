let s:mcp_tools = []
let s:sse_jobs = {}
let s:mcp_messages = []

function! copilot_chat#tools#mcp_function_call(function_name) abort
    let l:request_id = localtime()
    let l:request = {
        \ 'jsonrpc': '2.0',
        \ 'id': l:request_id,
        \ 'method': 'tools/call',
        \ 'params': {"name": a:function_name, "arguments": {}}
    \ }

    let tools_response = copilot_chat#http('POST', 'http://localhost:3000/mcp/messages', ['Content-Type: application/json'], l:request)
    call copilot_chat#log#write("MCP FUNCTION CALL")
    return tools_response
endfunction

function! copilot_chat#tools#fetch() abort
  return s:mcp_tools
endfunction

function! s:HandleMCPMessage(message)
    " Handle tools/list response
    if has_key(a:message, 'result') && has_key(a:message.result, 'tools')
        call copilot_chat#log#write("🛠️  Available Tools:")

        let l:tools = a:message.result.tools
        for l:i in range(len(l:tools))
            let l:tool = l:tools[l:i]
            let ff = {"type": "function", "function": {"name": l:tool['name'], 'description': get(l:tool, 'description', 'No description'), 'parameters': {"type": "object", "properties":  {}, "required": []}}}
            call add(s:mcp_tools, ff)

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
      call add(g:buffer_messages[g:copilot_chat_active_buffer], {'role': 'tool', 'content': l:mcp_output, 'tool_call_id': g:last_tool})
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

function! s:on_sse_output(job, data)
    let l:lines = split(a:data, '\n', 1)
    for l:line in l:lines
        if !empty(l:line)
            call s:ProcessSSELine(l:line)
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

function! s:send_tools_list_request(timer_id) abort
    let l:request_id = localtime()
    " Create JSON-RPC request for tools/list
    let l:request = {
        \ 'jsonrpc': '2.0',
        \ 'id': l:request_id,
        \ 'method': 'tools/list',
        \ 'params': {}
    \ }

    let tools_response = copilot_chat#http('POST', 'http://localhost:3000/mcp/messages', ['Content-Type: application/json'], l:request)
    call copilot_chat#log#write(tools_response)
    return tools_response
endfunction

function! s:ProcessSSELine(line)
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

function! s:start_sse_job(url) abort
  let l:cmd = s:build_curl_sse_command(a:url)
  let l:job_options = {
        \ 'out_cb': function('s:on_sse_output'),
        \ 'err_cb': function('s:on_sse_error'),
        \ 'exit_cb': function('s:on_sse_exit'),
        \ 'out_mode': 'raw',
        \ 'err_mode': 'raw'
  \ }
  let l:job = job_start(l:cmd, l:job_options)
  call timer_start(2000, function('s:send_tools_list_request'))
endfunction

function! copilot_chat#tools#load_mcp_servers(server_list)
  " TODO: actual format for finding /messages endpoint is not this simple
  " use the ruby example I have to do this same work

  for k in keys(a:server_list)
    call copilot_chat#log#write("TESTING SSE Connection")
    let details = a:server_list[k]
    let url = details['url']

    call s:start_sse_job(url)
  endfor
endfunction
