scriptencoding utf-8
let s:colors_gui = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
let s:colors_cterm = [46, 118, 154, 190, 226, 227, 228, 229, 230]
let s:color_index = 0
let s:chat_count = 1

function! copilot_chat#buffer#winsplit() abort
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
endfunction

function! copilot_chat#buffer#create() abort
  call copilot_chat#buffer#winsplit()

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

function! copilot_chat#buffer#has_active_chat() abort
  if g:active_chat_buffer == -1
    return 0
  endif

  if !bufexists(g:active_chat_buffer)
    return 0
  endif

  let l:buf = getbufinfo(g:active_chat_buffer)
  if empty(l:buf)
    return 0
  endif

  return 1
endfunction

function! copilot_chat#buffer#goto_active_chat() abort
  let l:current_buf = bufnr('%')
  if copilot_chat#buffer#has_active_chat() == 0
    return
  endif

  if l:current_buf == g:active_chat_buffer
    return
  endif
  let l:windows = getwininfo()
  for l:win in range(len(l:windows))
    let l:win_info = l:windows[l:win]
    if l:win_info.bufnr != g:active_chat_buffer ||
	    \ (l:win_info.height == 0 && l:win_info.width == 0)
      continue
    endif
    " We found an active chat buffer in the current window display, so
    " switch to it.
    execute l:win_info.winnr . ' wincmd w'
    return
  endfor

  " Not found in current visible windows, so create a new split
  call copilot_chat#buffer#winsplit()
  execute 'buffer ' . g:active_chat_buffer
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
  if copilot_chat#buffer#has_active_chat() == 0
    if g:copilot_chat_create_on_add_selection == 0
      return
    endif
    " TODO: copilot_chat#buffer#create should take an argument to
    " indicate if it should make the new buffer active or not.
    let l:curr_win = winnr()
    call copilot_chat#buffer#create()
    execute l:curr_win . 'wincmd w'
  endif

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

  " Goto to the active chat buffer, either old or newly created.
  if g:copilot_chat_jump_to_chat_on_add_selection == 1
    call copilot_chat#buffer#goto_active_chat()
  endif
endfunction

function! copilot_chat#buffer#append_message(message) abort
  call appendbufline(g:active_chat_buffer, '$', a:message)
endfunction

function! copilot_chat#buffer#welcome_message() abort
  call appendbufline(g:active_chat_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  call copilot_chat#buffer#add_input_separator()
endfunction

function! copilot_chat#buffer#set_active(bufnr) abort
  let l:bufnr = a:bufnr
  if l:bufnr ==# ''
    let l:bufnr = bufnr('%')
  endif

  if g:active_chat_buffer == l:bufnr
    return
  endif

  let bufinfo = getbufinfo(l:bufnr)
  if empty(bufinfo)
    echom 'Invlid buffer number'
    return
  endif

  " Check if the buffer is valid
  if getbufvar(l:bufnr, '&filetype') !=# 'copilot_chat'
    echom 'Buffer is not a Copilot Chat buffer'
    return
  endif

  " Set the active chat buffer to the current buffer
  let g:active_chat_buffer = l:bufnr
endfunction

function! copilot_chat#buffer#on_delete(bufnr) abort
  if g:copilot_chat_zombie_buffer != -1
	let l:bufinfo = getbufinfo(g:copilot_chat_zombie_buffer)
	if !empty(l:bufinfo) " Check if the buffer wasn't wiped out by the user
		execute 'bwipeout' . g:copilot_chat_zombie_buffer
	endif
	let g:copilot_chat_zombie_buffer = -1
  endif

  if g:active_chat_buffer != a:bufnr
    return
  endif
  " Unset the active chat buffer
  let g:copilot_chat_zombie_buffer = g:active_chat_buffer
  let g:active_chat_buffer = -1
endfunction

" vim:set ft=vim sw=2 sts=2 et:
