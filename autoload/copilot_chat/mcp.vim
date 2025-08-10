let s:popup_id = -1
let s:current_selection = 0
let s:popup_callback = v:null

function! copilot_chat#mcp#popup_filter(winid, key) abort
  if a:key ==? 'y' || a:key ==? "\<CR>"
    " User confirmed
    call s:popup_callback()
    call popup_close(a:winid, 'yes')
    return 1
  elseif a:key ==? 'n'
    " User declined
    call popup_close(a:winid, 'no')
    return 1
  elseif a:key ==? 'c' || a:key ==? "\<Esc>"
    " User cancelled
    call popup_close(a:winid, 'cancel')
    return 1
  endif

  " Ignore other keys
  return 1
endfunction

function! copilot_chat#mcp#define_popup_syntax() abort
  " Define highlight groups
  highlight MCPPopupNormal ctermfg=15 ctermbg=0 guifg=#ffffff guibg=#000000
  highlight MCPPopupBorder ctermfg=12 ctermbg=0 guifg=#5555ff guibg=#000000
  highlight MCPPopupLightBlue ctermfg=14 ctermbg=0 guifg=#87ceeb guibg=#000000
  highlight MCPPopupToolName ctermfg=11 ctermbg=0 guifg=#ffff00 guibg=#000000 cterm=italic gui=italic
  highlight MCPPopupGithub ctermfg=10 ctermbg=0 guifg=#00ff00 guibg=#000000 cterm=italic gui=italic
  highlight MCPPopupLightning ctermfg=11 ctermbg=0 guifg=#ffff00 guibg=#000000
  highlight MCPPopupParam ctermfg=14 ctermbg=0 guifg=#00ffff guibg=#000000
  highlight MCPPopupValue ctermfg=10 ctermbg=0 guifg=#00ff00 guibg=#000000
  highlight MCPPopupString ctermfg=9 ctermbg=0 guifg=#ff6666 guibg=#000000
  highlight MCPPopupButtons ctermfg=14 ctermbg=0 guifg=#00ffff guibg=#000000
endfunction

function! copilot_chat#mcp#apply_popup_syntax(popup_id, tool_name) abort
  let bufnr = winbufnr(a:popup_id)

  " Apply syntax rules to the popup buffer
  call setbufvar(bufnr, '&syntax', 'mcppopup')

  " Define syntax matches for this buffer with specific highlighting
  call win_execute(a:popup_id, 'syntax clear')

  " Lightning bolt in yellow
  call win_execute(a:popup_id, 'syntax match MCPPopupLightning /^⚡/')

  " Split the question line into parts for different highlighting
  call win_execute(a:popup_id, 'syntax match MCPPopupLightBlue /\(Do you want to call\|on\)/')
  call win_execute(a:popup_id, 'syntax match MCPPopupGithub /github?/')

  " Tool name in yellow italic - escape special regex characters
  let escaped_tool = escape(a:tool_name, '.*[]^$\/')
  call win_execute(a:popup_id, 'syntax match MCPPopupToolName /' . escaped_tool . '/')

  " Parameters and other elements
  call win_execute(a:popup_id, 'syntax match MCPPopupParam /^() [^:]*:/')
  call win_execute(a:popup_id, 'syntax match MCPPopupString /"[^"]*"/')
  call win_execute(a:popup_id, 'syntax match MCPPopupButtons /\[Y\]es • \[N\]o • \[C\]ancel/')
  call win_execute(a:popup_id, 'syntax match MCPPopupValue /^  [^"]\+$/')
endfunction

function! copilot_chat#mcp#function_call_prompt(success_callback, function_name, server_name, function_args)
  let s:popup_callback = a:success_callback
  let content = []
  let question_line = '⚡ Do you want to call ' . a:function_name. ' on ' . a:server_name . '?'
  call add(content, question_line)
  call add(content, '')

  " Add parameters with consistent formatting
  let l:params = json_decode(a:function_args)
  let max_key_length = 0
  for key in keys(l:params)
    if len(key) > max_key_length
      let max_key_length = len(key)
    endif
  endfor

  for [key, value] in items(l:params)
    let padded_key = printf('%-' . max_key_length . 's', key)
    call add(content, '() ' . padded_key . ':')

    if type(value) == v:t_string
      call add(content, '  "' . value . '"')
    elseif type(value) == v:t_number
      call add(content, '  ' . value)
    else
      call add(content, '  ' . string(value))
    endif
    call add(content, '')
  endfor

  " Remove trailing empty line and add buttons
  if !empty(content) && content[-1] ==# ''
    call remove(content, -1)
  endif
  call add(content, '')
  call add(content, '[Y]es • [N]o • [C]ancel')

  let l:options = {
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'borderhighlight': ['MCPPopupBorder'],
        \ 'highlight': 'MCPPopupNormal',
        \ 'padding': [1, 1, 1, 1],
        \ 'pos': 'center',
        \ 'minwidth': 50,
        \ 'filter': 'copilot_chat#mcp#popup_filter',
        \ 'mapping': 0,
        \ 'title': 'MCP Function Call',
        \ 'close': 'button'
        \ }
  let l:display_items = ['Do you want to call list_issues on github?', '', '{} state:', '    "open"']

  call copilot_chat#mcp#define_popup_syntax()
  let l:popup_id = popup_create(content, l:options)
  call copilot_chat#mcp#apply_popup_syntax(l:popup_id, 'magic')

  let l:bufnr = winbufnr(l:popup_id)
endfunction

function! copilot_chat#mcp#function_callback(function_request, function_arguments) abort
  let a:function_request['function']['arguments'] = a:function_arguments
  call add(g:buffer_messages[g:copilot_chat_active_buffer], {'role': 'assistant', 'content': '', 'tool_calls': [a:function_request]})
  let mcp_output = copilot_chat#tools#mcp_function_call(a:function_request['function']['name'])
endfunction

" MCP Servers & Tools display functionality
let g:copilot_mcp_popup_selection = 0
let s:display_items = []

function! s:build_display_items() abort
  let s:display_items = []

  if !exists('g:copilot_chat_mcp_servers') || empty(g:copilot_chat_mcp_servers)
    call add(s:display_items, 'No MCP servers configured')
    return s:display_items
  endif

  for server in g:copilot_chat_mcp_servers
    let status_icon = '⏳'
    if has_key(server, 'status')
      if server.status == 'success'
        let status_icon = '✅'
      elseif server.status == 'failed'
        let status_icon = '❌'
      endif
    endif

    let server_name = get(server, 'name', 'Unknown')
    call add(s:display_items, status_icon . ' ' . server_name)

    if has_key(server, 'tools') && !empty(server.tools)
      for tool in server.tools
        let tool_name = get(tool, 'name', 'unnamed tool')
        let tool_desc = get(tool, 'description', 'No description')
        call add(s:display_items, '    🔧 ' . tool_name . ' - ' . tool_desc)
      endfor
    else
      if has_key(server, 'status') && server.status == 'success'
        call add(s:display_items, '    No tools available')
      endif
    endif
    call add(s:display_items, '')
  endfor

  if !empty(s:display_items) && s:display_items[-1] == ''
    call remove(s:display_items, -1)
  endif

  return s:display_items
endfunction

function! copilot_chat#mcp#filter_popup(winid, key) abort
  if a:key ==? 'j' || a:key ==? "\<Down>"
    let g:copilot_mcp_popup_selection = (g:copilot_mcp_popup_selection + 1) % len(s:display_items)
  elseif a:key ==? 'k' || a:key ==? "\<Up>"
    let g:copilot_mcp_popup_selection = (g:copilot_mcp_popup_selection - 1 + len(s:display_items)) % len(s:display_items)
  elseif a:key ==? 'r' || a:key ==? "\<F5>"
    call s:refresh_display()
    call popup_settext(a:winid, s:display_items)
    let g:copilot_mcp_popup_selection = 0
  elseif a:key ==? "\<CR>" || a:key ==? "\<Space>"
    call popup_close(a:winid)
    return 1
  elseif a:key ==? "\<Esc>" || a:key ==? 'q'
    call popup_close(a:winid)
    return 1
  endif

  let l:display_items_copy = copy(s:display_items)
  if len(l:display_items_copy) > 0
    let l:display_items_copy[g:copilot_mcp_popup_selection] = '> ' . l:display_items_copy[g:copilot_mcp_popup_selection]
  endif

  call popup_settext(a:winid, l:display_items_copy)

  let l:bufnr = winbufnr(a:winid)
  call prop_add(g:copilot_mcp_popup_selection + 1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
  return 1
endfunction

function! s:refresh_display() abort
  call s:build_display_items()
endfunction

function! copilot_chat#mcp#show() abort
  call s:build_display_items()

  if empty(s:display_items)
    echo 'No MCP servers found'
    return
  endif

  let g:copilot_mcp_popup_selection = 0
  let l:display_items_copy = copy(s:display_items)
  if len(l:display_items_copy) > 0
    let l:display_items_copy[0] = '> ' . l:display_items_copy[0]
  endif

  execute 'syntax match SelectedText  /^> .*/'
  execute 'hi! SelectedText ctermfg=46 guifg=#33FF33'
  execute 'hi! GreenHighlight ctermfg=green ctermbg=NONE guifg=#33ff33 guibg=NONE'
  execute 'hi! PopupNormal ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE'

  let l:options = {
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'borderhighlight': ['DiffAdd'],
        \ 'highlight': 'PopupNormal',
        \ 'padding': [1, 1, 1, 1],
        \ 'pos': 'center',
        \ 'minwidth': 60,
        \ 'maxwidth': 120,
        \ 'maxheight': 25,
        \ 'filter': 'copilot_chat#mcp#filter_popup',
        \ 'mapping': 0,
        \ 'title': 'MCP Servers & Tools (r=refresh, q=quit)'
        \ }

  let l:popup_id = popup_create(l:display_items_copy, l:options)

  let l:bufnr = winbufnr(l:popup_id)
  call prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': l:bufnr})
  call prop_add(g:copilot_mcp_popup_selection + 1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
endfunction
