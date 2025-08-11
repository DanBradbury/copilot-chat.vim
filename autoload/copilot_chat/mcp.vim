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
let s:selectable_items = []  " Track which items are selectable (servers/tools)
let s:popup_scroll_offset = 0  " Track scroll position

" Global state for enabled/disabled tools and servers
let g:copilot_mcp_enabled_state = {}
let g:copilot_mcp_expanded_state = {}  " Track which servers are expanded

function! s:build_display_items() abort
  let s:display_items = []
  let s:selectable_items = []

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
    let server_id = 'server_' . server.id
    let enabled = get(g:copilot_mcp_enabled_state, server_id, v:true)
    let expanded = get(g:copilot_mcp_expanded_state, server_id, v:false)
    let toggle_icon = enabled ? '[✓]' : '[ ]'

    " Add expand/collapse indicator
    let expand_icon = ''
    if has_key(server, 'tools') && !empty(server.tools)
      let expand_icon = expanded ? '▼ ' : '▶ '
    endif

    call add(s:display_items, status_icon . ' ' . toggle_icon . ' ' . expand_icon . server_name)
    call add(s:selectable_items, {'type': 'server', 'id': server_id, 'server': server})

    " Only show tools if server is expanded
    if expanded
      if has_key(server, 'tools') && !empty(server.tools)
        for tool in server.tools
          let tool_name = get(tool, 'name', 'unnamed tool')
          let tool_id = 'tool_' . server.id . '_' . tool_name
          let tool_enabled = get(g:copilot_mcp_enabled_state, tool_id, v:true)
          let tool_toggle_icon = tool_enabled ? '[✓]' : '[ ]'

          call add(s:display_items, '      🔧 ' . tool_toggle_icon . ' ' . tool_name)
          call add(s:selectable_items, {'type': 'tool', 'id': tool_id, 'server': server, 'tool': tool})
        endfor
      else
        if has_key(server, 'status') && server.status == 'success'
          call add(s:display_items, '      No tools available')
          call add(s:selectable_items, {})
        endif
      endif
    endif
    call add(s:display_items, '')
    call add(s:selectable_items, {})
  endfor

  if !empty(s:display_items) && s:display_items[-1] == ''
    call remove(s:display_items, -1)
    call remove(s:selectable_items, -1)
  endif

  return s:display_items
endfunction

function! copilot_chat#mcp#filter_popup(winid, key) abort
  if a:key ==? 'j' || a:key ==? "\<Down>"
    let g:copilot_mcp_popup_selection = (g:copilot_mcp_popup_selection + 1) % len(s:display_items)
    call s:update_popup_display(a:winid)
  elseif a:key ==? 'k' || a:key ==? "\<Up>"
    let g:copilot_mcp_popup_selection = (g:copilot_mcp_popup_selection - 1 + len(s:display_items)) % len(s:display_items)
    call s:update_popup_display(a:winid)
  elseif a:key ==? 'l' || a:key ==? "\<Right>"
    call s:expand_server()
    call s:refresh_display()
    call s:update_popup_display(a:winid)
  elseif a:key ==? 'h' || a:key ==? "\<Left>"
    call s:collapse_server()
    call s:refresh_display()
    call s:update_popup_display(a:winid)
  elseif a:key ==? 'r' || a:key ==? "\<F5>"
    call s:refresh_display()
    let g:copilot_mcp_popup_selection = 0
    let s:popup_scroll_offset = 0
    call s:update_popup_display(a:winid)
  elseif a:key ==? "\<CR>" || a:key ==? "\<Space>"
    call s:toggle_item()
    call s:refresh_display()
    call s:update_popup_display(a:winid)
  elseif a:key ==? 't'
    call s:toggle_item()
    call s:refresh_display()
    call s:update_popup_display(a:winid)
  elseif a:key ==? "\<Esc>" || a:key ==? 'q'
    call popup_close(a:winid)
    return 1
  endif

  return 1
endfunction

function! s:refresh_display() abort
  call s:build_display_items()
endfunction

" Expand server (show tools)
function! s:expand_server() abort
  if g:copilot_mcp_popup_selection >= len(s:selectable_items)
    return
  endif

  let item = s:selectable_items[g:copilot_mcp_popup_selection]
  if empty(item) || item.type != 'server'
    return
  endif

  " Only expand if server has tools
  if has_key(item.server, 'tools') && !empty(item.server.tools)
    let g:copilot_mcp_expanded_state[item.id] = v:true
    call copilot_chat#mcp#save_expanded_state()
  endif
endfunction

" Collapse server (hide tools)
function! s:collapse_server() abort
  if g:copilot_mcp_popup_selection >= len(s:selectable_items)
    return
  endif

  let item = s:selectable_items[g:copilot_mcp_popup_selection]
  if empty(item) || item.type != 'server'
    return
  endif

  let g:copilot_mcp_expanded_state[item.id] = v:false
  call copilot_chat#mcp#save_expanded_state()
endfunction

" Update popup display with scrolling support
function! s:update_popup_display(winid) abort
  let popup_height = popup_getpos(a:winid).height - 2  " Account for borders/padding
  let total_items = len(s:display_items)

  if total_items == 0
    return
  endif

  " Calculate scroll offset with early engagement (scroll when within 12 items of edge)
  let scroll_margin = 12
  let selection_pos = g:copilot_mcp_popup_selection

  " Scroll up if selection is too close to top
  if selection_pos <= s:popup_scroll_offset + scroll_margin
    let s:popup_scroll_offset = max([0, selection_pos - scroll_margin])
  endif

  " Scroll down if selection is too close to bottom
  if selection_pos >= s:popup_scroll_offset + popup_height - scroll_margin - 1
    let s:popup_scroll_offset = min([max([0, total_items - popup_height]), selection_pos - popup_height + scroll_margin + 1])
  endif

  " Ensure scroll offset stays within bounds
  let max_scroll = max([0, total_items - popup_height])
  let s:popup_scroll_offset = max([0, min([s:popup_scroll_offset, max_scroll])])

  " Get visible items
  let visible_end = min([s:popup_scroll_offset + popup_height, total_items])
  let visible_items = s:display_items[s:popup_scroll_offset : visible_end - 1]

  " Add selection indicator to visible items
  let l:display_items_copy = copy(visible_items)
  let selection_in_view = g:copilot_mcp_popup_selection - s:popup_scroll_offset

  if selection_in_view >= 0 && selection_in_view < len(l:display_items_copy)
    let l:display_items_copy[selection_in_view] = '> ' . l:display_items_copy[selection_in_view]
  endif

  " Add scroll indicators if needed
  if s:popup_scroll_offset > 0
    let l:display_items_copy[0] = '↑ ' . l:display_items_copy[0]
  endif
  if visible_end < total_items
    let l:display_items_copy[-1] = '↓ ' . l:display_items_copy[-1]
  endif

  call popup_settext(a:winid, l:display_items_copy)

  " Update highlighting
  let l:bufnr = winbufnr(a:winid)
  if selection_in_view >= 0 && selection_in_view < len(l:display_items_copy)
    call prop_clear(l:bufnr)
    call prop_add(selection_in_view + 1, 1, {
          \ 'type': 'highlight',
          \ 'length': 60,
          \ 'bufnr': l:bufnr
          \ })
  endif
endfunction

function! copilot_chat#mcp#show() abort
  " Load saved states
  call copilot_chat#mcp#load_enabled_state()
  call copilot_chat#mcp#load_expanded_state()
  call s:build_display_items()

  if empty(s:display_items)
    echo 'No MCP servers found'
    return
  endif

  let g:copilot_mcp_popup_selection = 0
  let s:popup_scroll_offset = 0

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
        \ 'minwidth': 80,
        \ 'maxwidth': &columns - 4,
        \ 'minheight': 30,
        \ 'maxheight': &lines - 6,
        \ 'filter': 'copilot_chat#mcp#filter_popup',
        \ 'mapping': 0,
        \ 'title': 'MCP Servers & Tools (Space/t=toggle, →=expand, ←=collapse, r=refresh, q=quit)'
        \ }

  " Create popup with initial empty content
  let l:popup_id = popup_create(['Loading...'], l:options)

  let l:bufnr = winbufnr(l:popup_id)
  call prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': l:bufnr})

  " Initialize the display with scrolling support
  call s:update_popup_display(l:popup_id)
endfunction

" Toggle the enabled state of the currently selected item
function! s:toggle_item() abort
  if g:copilot_mcp_popup_selection >= len(s:selectable_items)
    return
  endif

  let item = s:selectable_items[g:copilot_mcp_popup_selection]
  if empty(item)
    return
  endif

  if item.type == 'server'
    let current_state = get(g:copilot_mcp_enabled_state, item.id, v:true)
    let new_state = !current_state
    let g:copilot_mcp_enabled_state[item.id] = new_state

    " When toggling a server, set all its tools to the same state
    if has_key(item.server, 'tools')
      for tool in item.server.tools
        let tool_id = 'tool_' . item.server.id . '_' . tool.name
        let g:copilot_mcp_enabled_state[tool_id] = new_state
      endfor
    endif
  elseif item.type == 'tool'
    let current_state = get(g:copilot_mcp_enabled_state, item.id, v:true)
    let g:copilot_mcp_enabled_state[item.id] = !current_state
  endif

  " Save state after any toggle
  call copilot_chat#mcp#save_enabled_state()
endfunction

" Get filtered list of enabled tools for async_request
function! copilot_chat#mcp#get_enabled_tools() abort
  " Load state first to ensure we have the latest settings
  call copilot_chat#mcp#load_enabled_state()
  let enabled_tools = []

  for tool in g:mcp_tools
    let tool_name = tool.function.name
    let server = copilot_chat#tools#find_server_by_tool_name(tool_name)

    if empty(server)
      continue
    endif

    let server_id = 'server_' . server.id
    let tool_id = 'tool_' . server.id . '_' . tool_name

    let tool_enabled = get(g:copilot_mcp_enabled_state, tool_id, v:true)

    if tool_enabled
      call add(enabled_tools, tool)
    endif
  endfor

  return enabled_tools
endfunction

" Save enabled state to file
function! copilot_chat#mcp#save_enabled_state() abort
  let config_dir = expand('~/.config/copilot-chat-vim')
  if !isdirectory(config_dir)
    call mkdir(config_dir, 'p')
  endif

  let config_file = config_dir . '/mcp_enabled_state.json'
  let json_data = json_encode(g:copilot_mcp_enabled_state)
  call writefile([json_data], config_file)
endfunction

" Load enabled state from file
function! copilot_chat#mcp#load_enabled_state() abort
  let config_file = expand('~/.config/copilot-chat-vim/mcp_enabled_state.json')
  if filereadable(config_file)
    try
      let json_data = readfile(config_file)[0]
      let g:copilot_mcp_enabled_state = json_decode(json_data)
    catch
      " If file is corrupted, start with empty state
      let g:copilot_mcp_enabled_state = {}
    endtry
  else
    let g:copilot_mcp_enabled_state = {}
  endif
endfunction

" Save expanded state to file
function! copilot_chat#mcp#save_expanded_state() abort
  let config_dir = expand('~/.config/copilot-chat-vim')
  if !isdirectory(config_dir)
    call mkdir(config_dir, 'p')
  endif

  let config_file = config_dir . '/mcp_expanded_state.json'
  let json_data = json_encode(g:copilot_mcp_expanded_state)
  call writefile([json_data], config_file)
endfunction

" Load expanded state from file
function! copilot_chat#mcp#load_expanded_state() abort
  let config_file = expand('~/.config/copilot-chat-vim/mcp_expanded_state.json')
  if filereadable(config_file)
    try
      let json_data = readfile(config_file)[0]
      let g:copilot_mcp_expanded_state = json_decode(json_data)
    catch
      " If file is corrupted, start with empty state
      let g:copilot_mcp_expanded_state = {}
    endtry
  else
    let g:copilot_mcp_expanded_state = {}
  endif
endfunction
