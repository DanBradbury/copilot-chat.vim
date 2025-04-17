scriptencoding utf-8
let s:colors_gui = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
let s:colors_cterm = [46, 118, 154, 190, 226, 227, 228, 229, 230]
let s:color_index = 0
let s:chat_count = 1
let s:completion_active = 0

function! copilot_chat#buffer#winsplit() abort
  let l:position = copilot_chat#config#get_value('window_position', 'right')

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
  let g:copilot_chat_active_buffer = bufnr('%')
  let b:added_syntaxes = []
  call copilot_chat#buffer#welcome_message()
  return g:copilot_chat_active_buffer
endfunction

function! copilot_chat#buffer#has_active_chat() abort
  if g:copilot_chat_active_buffer == -1
    return 0
  endif

  if !bufexists(g:copilot_chat_active_buffer)
    return 0
  endif

  let l:buf = getbufinfo(g:copilot_chat_active_buffer)
  if empty(l:buf)
    return 0
  endif

  return 1
endfunction

function! copilot_chat#buffer#focus_active_chat() abort
  let l:current_buf = bufnr('%')
  if copilot_chat#buffer#has_active_chat() == 0
    return
  endif

  if l:current_buf == g:copilot_chat_active_buffer
    return
  endif
  let l:windows = getwininfo()
  for l:win in range(len(l:windows))
    let l:win_info = l:windows[l:win]
    if l:win_info.bufnr != g:copilot_chat_active_buffer ||
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
  execute 'buffer ' . g:copilot_chat_active_buffer
endfunction

function! copilot_chat#buffer#add_input_separator() abort
  let l:width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
  let l:separator = ' ' . repeat('━', l:width)
  call copilot_chat#buffer#append_message(l:separator)
  call copilot_chat#buffer#append_message('')
endfunction

function! copilot_chat#buffer#waiting_for_response() abort
  call copilot_chat#buffer#append_message('Waiting for response')
  let s:waiting_timer = timer_start(500, {-> copilot_chat#buffer#update_waiting_dots()}, {'repeat': -1})
endfunction

function! copilot_chat#buffer#update_waiting_dots() abort
  if !bufexists(g:copilot_chat_active_buffer)
    call timer_stop(s:waiting_timer)
    return 0
  endif

  let l:lines = getbufline(g:copilot_chat_active_buffer, '$')
  if empty(l:lines)
    call timer_stop(s:waiting_timer)
    return 0
  endif

  let l:current_text = l:lines[0]
  if l:current_text =~? '^Waiting for response'
      let l:dots = len(matchstr(l:current_text, '\..*$'))
      let l:new_dots = (l:dots % 3) + 1
      call setbufline(g:copilot_chat_active_buffer, '$', 'Waiting for response' . repeat('.', l:new_dots))
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
    call copilot_chat#buffer#focus_active_chat()
  endif
endfunction

function! copilot_chat#buffer#append_message(message) abort
  call appendbufline(g:copilot_chat_active_buffer, '$', a:message)
endfunction

function! copilot_chat#buffer#welcome_message() abort
  call appendbufline(g:copilot_chat_active_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  call copilot_chat#buffer#add_input_separator()
endfunction

function! copilot_chat#buffer#set_active(bufnr) abort
  let l:bufnr = a:bufnr
  if l:bufnr ==# ''
    let l:bufnr = bufnr('%')
  endif

  if g:copilot_chat_active_buffer == l:bufnr
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
  let g:copilot_chat_active_buffer = l:bufnr
endfunction

function! copilot_chat#buffer#on_delete(bufnr) abort
  if g:copilot_chat_zombie_buffer != -1
	let l:bufinfo = getbufinfo(g:copilot_chat_zombie_buffer)
	if !empty(l:bufinfo) " Check if the buffer wasn't wiped out by the user
		execute 'bwipeout' . g:copilot_chat_zombie_buffer
	endif
	let g:copilot_chat_zombie_buffer = -1
  endif

  if g:copilot_chat_active_buffer != a:bufnr
    return
  endif
  " Unset the active chat buffer
  let g:copilot_chat_zombie_buffer = g:copilot_chat_active_buffer
  let g:copilot_chat_active_buffer = -1
endfunction

function! copilot_chat#buffer#resize() abort
  if g:copilot_chat_active_buffer == -1
    return
  endif

  let currtab = tabpagenr()

  for tabnr in range(1, tabpagenr('$'))
    exec 'normal!' tabnr . 'gt'
    let currwin = winnr()

    for winnr in range(1, winnr('$'))
      exec winnr . 'wincmd w'
      if &filetype !=# 'copilot_chat'
        continue
      endif
      let l:width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
      let curpos = getcurpos()
      exec '%s/^ ━\+/ ' . repeat('━', l:width) . '/ge'
      exec '%s/^ ━\+/ ' . repeat('━', l:width) . '/ge'
      call setpos('.', curpos)
    endfor

    exec currwin . 'wincmd w'
  endfor

  exec 'normal!' currtab . 'gt'
endfunction

function! copilot_chat#buffer#apply_code_block_syntax() abort
  let lines = getline(1, '$')
  let total_lines = len(lines)

  let in_code_block = 0
  let current_lang = ''
  let start_line = 0
  let block_count = 0

  for linenum in range(total_lines)
    let line = lines[linenum]

    if !in_code_block && line =~# '^```\s*\([a-zA-Z0-9_+-]\+\)$'
      let in_code_block = 1
      let current_lang = matchstr(line, '^```\s*\zs[a-zA-Z0-9_+-]\+\ze$')
      let start_line = linenum + 1  " Start on next line

    elseif in_code_block && line =~# '^```\s*$'
      let end_line = linenum

      if start_line < end_line
        call copilot_chat#buffer#highlight_code_block(start_line, end_line, current_lang, block_count)
        let block_count += 1
      endif

      let in_code_block = 0
      let current_lang = ''
    endif
  endfor
  redraw
endfunction

function! copilot_chat#buffer#highlight_code_block(start_line, end_line, lang, block_id) abort
  let lang = a:lang

  " Handle common aliases
  if lang ==# 'js'
    let lang = 'javascript'
  elseif lang ==# 'ts'
    let lang = 'typescript'
  elseif lang ==# 'py'
    let lang = 'python'
  endif

  let syn_group = 'CopilotCode_' . lang . '_' . a:block_id

  let syntax_file = findfile('syntax/' . lang . '.vim', &runtimepath)
  if !empty(syntax_file)
    if index(b:added_syntaxes, '@' . lang) == -1
      if exists('b:current_syntax')
        unlet b:current_syntax
      endif
      execute 'syntax include @' . lang . ' ' . syntax_file

      call add(b:added_syntaxes, '@' . lang)
    endif
    " Define syntax region for this specific code block
    let cmd = 'syntax region ' . syn_group
    let cmd .= ' start=/\%' . (a:start_line + 1) . 'l/'
    let cmd .= ' end=/\%' . (a:end_line + 1) . 'l/'
    let cmd .= ' contains=@' . lang
    execute cmd
  endif
endfunction

function! copilot_chat#buffer#check_for_macro() abort
  let current_line = getline('.')
  let cursor_pos = col('.')
  let before_cursor = strpart(current_line, 0, cursor_pos)
  if current_line =~# '/tab all'
    " Get the position where the pattern starts
    let pattern_start = match(before_cursor, '/tab all')

    " Delete the pattern
    call cursor(line('.'), pattern_start + 1)
    exec 'normal! d' . len('/tab all') . 'l'

    " Get current buffer number to exclude it
    let current_bufnr = bufnr('%')

    " Generate list of tabs with #file: prefix, excluding current buffer
    let tab_list = []
    for i in range(1, tabpagenr('$'))
      let buffers = tabpagebuflist(i)
      for buf in buffers
        let filename = bufname(buf)
        " Only add if it's not the current buffer and has a filename
        if filename !=# '' && filename !~# 'CopilotChat'
          " Use the relative path format instead of just the base filename
          let display_name = '#file:' . filename
          call add(tab_list, display_name)
        endif
      endfor
      "let winnr = tabpagewinnr(i)
      "let buf_nr = buflist[winnr - 1]
      "let filename = bufname(buf_nr)

    endfor

    " Insert the tab list at cursor position, one per line
    if len(tab_list) > 0
      " Add a newline at the end of the text to be inserted
      let tabs_text = join(tab_list, "\n") . "\n"
      exec 'normal! i' . tabs_text
    else
      exec "normal! iNo other tabs found\n"
    endif

    " Position cursor on the empty line
    call cursor(line('.'), 1)
  elseif current_line =~# '#file:'
    if s:completion_active == 1 && !pumvisible()
      let s:completion_active = 0
    endif
    if s:completion_active == 0
      " TODO: should be resetting this after we do this
      " let saved_completeopt = &completeopt
      " call timer_start(0, {-> execute('let &completeopt = "' . saved_completeopt . '"')})
      set completeopt=menu,menuone,noinsert,noselect
      let line = getline('.')
      let start = match(line, '#file:') + 6
      let typed = strpart(line, start, col('.') - start - 1)
      if typed !=# '' && filereadable(typed) && !isdirectory(typed)
        return
      endif

      let is_git_repo = system('git rev-parse --is-inside-work-tree 2>/dev/null')

      if v:shell_error == 0  " We are in a git repo
        let files = systemlist('git ls-files --cached --others --exclude-standard')
      else
        let files = glob('**/*', 0, 1)
      endif

      " Filter out directories and prepare completion items
      let matches = []
      for file in files
        if !isdirectory(file) && file =~? typed
          call add(matches, file)
        endif
      endfor

      " Show the completion menu
      call complete(start+1, matches)
      let s:completion_active = 1
    endif
  endif
endfunction

" vim:set ft=vim sw=2 sts=2 et:
