scriptencoding utf-8

let s:curl_output = []
" XXX: I don't like this but for now its working
let g:last_tool = {'call_id': '-1', 'server_id': '-1', 'args': ''}

function! copilot_chat#api#async_request(messages, file_list) abort
  let l:chat_token = copilot_chat#auth#verify_signin()
  let s:curl_output = []
  let l:url = 'https://api.githubcopilot.com/chat/completions'

  " for knowledge bases its just an attachment as the content
  "{'content': '<attachment id="kb:Name">\n#kb:\n</attachment>', 'role': 'user'}
  " for files similar
  for file in a:file_list
    let l:file_content = readfile(file)
    let full_path = fnamemodify(file, ':p')
    " TODO: get the filetype instead of just markdown
    let l:c = '<attachment id="' . file . '">\n````markdown\n<!-- filepath: ' . full_path . ' -->\n' . join(l:file_content, "\n") . '\n```</attachment>'
    call add(a:messages, {'content': l:c, 'role': 'user'})
  endfor

  let l:tools = copilot_chat#mcp#get_enabled_tools()
  "let l:tools = []
  "call add(l:tools, {"function": {"name": "semantic_search","description": "Run a natural language search for relevant code or documentation comments from the user's current workspace. Returns relevant code snippets from the user's current workspace if it is large, or the full contents of the workspace if it is small.", "parameters": {"type": "object", "properties": {"query": {"type": "string","description": "The query to search the codebase for. Should contain all relevant context. Should ideally be text that might appear in the codebase, such as function names, variable names, or comments."}},"required": ["query"]}},"type": "function"})

  let l:data = json_encode({
        \ 'intent': v:false,
        \ 'model': copilot_chat#models#current(),
        \ 'temperature': 0,
        \ 'top_p': 1,
        \ 'n': 1,
        \ 'stream': v:true,
        \ 'messages': a:messages,
        \ 'tools': l:tools
        \ })
  call copilot_chat#log#write(l:data)

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

  if has('nvim')
    let job = jobstart(l:curl_cmd, {
      \ 'on_stdout': {chan_id, data, name->copilot_chat#api#handle_job_output(chan_id, data)},
      \ 'on_exit': {chan_id, data, name->copilot_chat#api#handle_job_close(chan_id, data)},
      \ 'on_stderr': {chan_id, data, name->copilot_chat#api#handle_job_error(chan_id, data)},
      \ 'stdout_buffered': v:true,
      \ 'stderr_buffered': v:true
      \ })
  else
    let job = job_start(l:curl_cmd, {
      \ 'out_cb': function('copilot_chat#api#handle_job_output'),
      \ 'exit_cb': function('copilot_chat#api#handle_job_close'),
      \ 'err_cb': function('copilot_chat#api#handle_job_error')
      \ })
  endif
  call copilot_chat#buffer#waiting_for_response()

  return job
endfunction

function! copilot_chat#api#handle_job_output(channel, msg) abort
  if type(a:msg) == v:t_list
    for data in a:msg
      if data =~? '^data: {'
        call add(s:curl_output, data)
      endif
    endfor
  else
    call add(s:curl_output, a:msg)
  endif
endfunction

function! copilot_chat#api#handle_job_close(channel, msg) abort
  call deletebufline(g:copilot_chat_active_buffer, '$')
  let l:result = ''
  let l:function_request = {}
  let l:function_arguments = ""
  for line in s:curl_output
    if line =~? '^data: {'
      let l:json_completion = json_decode(line[6:])
      " MCP Land
      if line =~? 'tool_calls'
        call copilot_chat#log#write("TOOL CALL")
        call copilot_chat#log#write(line)
        if has_key(l:json_completion.choices[0].delta, 'tool_calls') && has_key(l:json_completion.choices[0].delta.tool_calls[0].function, 'name')
          let l:function_name = l:json_completion.choices[0].delta.tool_calls[0].function.name

          call copilot_chat#buffer#append_message('MCP FUNCTION CALL: ' . l:function_name)
          " fetch the details for the tool
          let details = copilot_chat#tools#find_server_by_tool_name(l:function_name)
          let call_id = l:json_completion.id
          let l:function_request = {'type': 'function', 'id': call_id, 'function': {'name': l:function_name}}
          let g:last_tool['call_id'] = l:json_completion.id
          let g:last_tool['server_id'] = details.id
          let g:last_tool['args'] = ''
          let server_name = details.name
        elseif line =~? 'finish_reason'
          call copilot_chat#mcp#function_call_prompt(function('copilot_chat#mcp#function_callback', [l:function_request, g:last_tool['args']]), l:function_request['function']['name'], server_name, g:last_tool['args'])
        else
          let g:last_tool['args'] .= l:json_completion.choices[0].delta.tool_calls[0].function.arguments
        endif
      " elseif has_key(l:json_completion, 'choices') && len(l:json_completion.choices) > 0 && has_key(l:json_completion.choices[0], 'delta') && has_key(l:json_completion.choices[0].delta, 'content') && type(l:json_completion.choices[0].delta.content) != type(v:null)
      else
        try
          let l:content = l:json_completion.choices[0].delta.content
          if type(l:content) != type(v:null)
            let l:result .= l:content
          endif
        catch
          let l:result .= ""
        endtry
      endif
    endif
  endfor

  call copilot_chat#log#write('result printing')
  call copilot_chat#log#write(l:result)

  if l:result ==# ""
    call copilot_chat#log#write('yabadabadoo')
  else
    let l:response = split(l:result, "\n")
    let l:width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff

    let l:separator = ' '
    let l:separator .= repeat('━', l:width)
    let l:response_start = line('$') + 1

    call copilot_chat#buffer#append_message(l:separator)
    call copilot_chat#buffer#append_message(l:response)
    call copilot_chat#buffer#add_input_separator()

    let l:wrap_width = l:width + 2
    let l:softwrap_lines = 0
    for line in l:response
      if strwidth(line) > l:wrap_width
        let l:softwrap_lines += ceil(strwidth(line) / l:wrap_width)
      else
        let l:softwrap_lines += 1
      endif
    endfor

    let l:total_response_length = l:softwrap_lines + 2
    let l:height = winheight(0)
    if l:total_response_length >= l:height
      execute 'normal! ' . l:response_start . 'Gzt'
    else
      execute 'normal! G'
    endif
    call setcursorcharpos(0, 3)
  endif

endfunction

function! copilot_chat#api#handle_job_error(channel, msg) abort
  if type(a:msg) == v:t_list
    let l:filtered_errors = filter(copy(a:msg), '!empty(v:val)')
    if len(l:filtered_errors) > 0
      echom l:filtered_errors
    endif
  else
    echom a:msg
  endif
endfunction

function! copilot_chat#api#fetch_models(chat_token) abort
  let l:chat_headers = [
    \ 'Content-Type: application/json',
    \ 'Authorization: Bearer ' . a:chat_token,
    \ 'Editor-Version: vscode/1.80.1'
    \ ]

  let l:response = copilot_chat#http('GET', 'https://api.githubcopilot.com/models', l:chat_headers, {})[0]
  try
    let l:json_response = json_decode(l:response)
    let l:model_list = []
    for item in l:json_response.data
        if has_key(item, 'id')
            call add(l:model_list, item.id)
        endif
    endfor
    return l:model_list
  endtry

  return l:response
endfunction

" vim:set ft=vim sw=2 sts=2 et:
