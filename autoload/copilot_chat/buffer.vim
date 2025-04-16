scriptencoding utf-8
let s:colors_gui = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
let s:colors_cterm = [46, 118, 154, 190, 226, 227, 228, 229, 230]
let s:color_index = 0
let s:chat_count = 1

function! copilot_chat#buffer#create() abort
  let l:position = copilot_chat#config#get('window_position', 'right')

  " Create split based on position
  if l:position ==# 'right'
    rightbelow vsplit
  elseif l:position ==# 'left'
    leftabove vsplit
  elseif l:position ==# 'top'
    topleft split
  elseif l:position ==# 'bottom'
    botright split
  endif

  enew

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=copilot_chat

  " Set buffer name
  execute 'file CopilotChat-' . s:chat_count
  let s:chat_count += 1

  " Save buffer number for reference
  let g:active_chat_buffer = bufnr('%')
  call copilot_chat#buffer#welcome_message()
  return g:active_chat_buffer
endfunction

function! copilot_chat#buffer#add_input_separator() abort
  let l:width = winwidth(0) - 2
  let l:separator = ' ' . repeat('━', l:width)
  call copilot_chat#buffer#append_message(l:separator)
  call copilot_chat#buffer#append_message('')
endfunction

function! copilot_chat#buffer#waiting_for_response() abort
  call copilot_chat#buffer#append_message('Waiting for response')
  let s:waiting_timer = timer_start(500, {-> copilot_chat#buffer#update_waiting_dots()}, {'repeat': -1})
endfunction

function! copilot_chat#buffer#update_waiting_dots() abort
  if !bufexists(g:active_chat_buffer)
    call timer_stop(s:waiting_timer)
    return 0
  endif

  let l:lines = getbufline(g:active_chat_buffer, '$')
  if empty(l:lines)
    call timer_stop(s:waiting_timer)
    return 0
  endif

  let l:current_text = l:lines[0]
  if l:current_text =~? '^Waiting for response'
      let l:dots = len(matchstr(l:current_text, '\..*$'))
      let l:new_dots = (l:dots % 3) + 1
      call setbufline(g:active_chat_buffer, '$', 'Waiting for response' . repeat('.', l:new_dots))
    let s:color_index = (s:color_index + 1) % len(s:colors_gui)
    execute 'highlight CopilotWaiting guifg=' . s:colors_gui[s:color_index] . ' ctermfg=' . s:colors_cterm[s:color_index]
  endif
  return 1
endfunction

function! copilot_chat#buffer#add_selection() abort
  " Save the current register and selection type
  let l:save_reg = @"
  let l:save_regtype = getregtype('"')
  let l:filetype = &filetype

  " Get the visual selection
  normal! gv"xy

  " Get the content of the visual selection
  let l:selection = getreg('x')

  " Restore the original register and selection type
  call setreg('"', l:save_reg, l:save_regtype)
  call copilot_chat#buffer#append_message('```' . l:filetype)
  call copilot_chat#buffer#append_message(split(l:selection, "\n"))
  call copilot_chat#buffer#append_message('```')
endfunction

function! copilot_chat#buffer#append_message(message) abort
  call appendbufline(g:active_chat_buffer, '$', a:message)
endfunction

function! copilot_chat#buffer#welcome_message() abort
  call appendbufline(g:active_chat_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  call copilot_chat#buffer#add_input_separator()
endfunction
