" Global variable to store the log buffer number
let g:copilot_chat_log_bufnr = -1
function! IsJSON(str)
  try
    call json_decode(a:str)
    return 1
  catch
    return 0
  endtry
endfunction

" Complete pretty printing solution using Vim's built-in functions
function! PrettyPrintJSON(json_string)
  try
    let json_obj = json_decode(a:json_string)
    return s:JSONStringify(json_obj, 0)
  catch
    return a:json_string
  endtry
endfunction

function! s:JSONStringify(obj, indent)
  let ind = repeat('  ', a:indent)

  if type(a:obj) == v:t_dict
    if empty(a:obj)
      return '{}'
    endif

    let lines = ['{']
    let items = []

    for [key, val] in items(a:obj)
      let formatted_val = s:JSONStringify(val, a:indent + 1)
      call add(items, repeat('  ', a:indent + 1) . '"' . escape(key, '"\') . '": ' . formatted_val)
    endfor

    call extend(lines, items)
    call add(lines, ind . '}')

    return join(lines, "\n")

  elseif type(a:obj) == v:t_list
    if empty(a:obj)
      return '[]'
    endif

    let lines = ['[']
    let items = []

    for item in a:obj
      call add(items, repeat('  ', a:indent + 1) . s:JSONStringify(item, a:indent + 1))
    endfor

    call extend(lines, items)
    call add(lines, ind . ']')

    return join(lines, "\n")

  elseif type(a:obj) == v:t_string
    return '"' . escape(a:obj, '"\') . '"'

  elseif type(a:obj) == v:t_number || type(a:obj) == v:t_float
    return string(a:obj)

  elseif type(a:obj) == v:t_bool
    return a:obj ? 'true' : 'false'

  elseif a:obj is v:null
    return 'null'

  else
    return string(a:obj)
  endif
endfunction

" Function to write log messages to the custom buffer
function! copilot_chat#log#write(message)
  if exists("g:copilot_chat_debug") && (g:copilot_chat_log_bufnr == -1 || !bufexists(g:copilot_chat_log_bufnr))
    let current_win = win_getid()
    execute 'botright new copilot-chat-log'
    let g:copilot_chat_log_bufnr = bufnr('%')

    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nowrap
    "setlocal nomodifiable
    setlocal filetype=log
    setlocal nonumber
    setlocal norelativenumber

    setlocal modifiable
    call setline(1, '=== Copilot Chat Log ===')
    call setline(2, '')
    "setlocal nomodifiable

    call win_gotoid(current_win)
  endif

  " Format the message
  let timestamp = strftime('[%Y-%m-%d %H:%M:%S] ')

  " Check if the message is JSON and pretty print it
  if IsJSON(a:message)
    let pretty_json = PrettyPrintJSON(a:message)
    let lines = split(pretty_json, "\n")

    " Add timestamp to first line
    let lines[0] = timestamp . lines[0]

    " Indent subsequent lines
    for i in range(1, len(lines) - 1)
      let lines[i] = repeat(' ', len(timestamp)) . lines[i]
    endfor

    " Append all lines
    for line in lines
      call appendbufline(g:copilot_chat_log_bufnr, '$', line)
    endfor
  else
    " Regular message
    call appendbufline(g:copilot_chat_log_bufnr, '$', timestamp . a:message)
  endif
endfunction

" Helper function to view the log buffer
function! CopilotViewLog()
  if g:copilot_chat_log_bufnr != -1 && bufexists(g:copilot_chat_log_bufnr)
    execute 'buffer ' . g:copilot_chat_log_bufnr
  else
    echo "No log buffer exists yet"
  endif
endfunction

" Command to easily view logs
"command! CopilotLog call copilot_chat#log#write()
