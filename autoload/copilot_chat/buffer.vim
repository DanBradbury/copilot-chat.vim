vim9script
scriptencoding utf-8

import autoload 'copilot_chat/config.vim' as config

var colors_gui: list<string> = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
var colors_cterm: list<number> = [46, 118, 154, 190, 226, 227, 228, 229, 230]
var color_index: number = 0
var chat_count: number = 1
var completion_active: number = 0
var syntax_timer: number = -1
var file_completion_timer: number = -1
var file_list_cache: list<string> = []
var file_list_cache_time: number = 0
var copilot_list_chat_buffer: number = get(g:, 'copilot_list_chat_buffer', 0)
var copilot_chat_open_on_toggle: number = get(g:, 'copilot_chat_open_on_toggle', 1)
var waiting_timer: number = 0

def WindowSplit(): void
  var position: string = config.GetValue('window_position', 'right')
  if exists('g:copilot_chat_window_position')
    position = g:copilot_chat_window_position
  endif

  # Create split based on position
  if position ==# 'right'
    rightbelow vsplit
  elseif position ==# 'left'
    leftabove vsplit
  elseif position ==# 'top'
    topleft split
  elseif position ==# 'bottom'
    botright split
  endif
enddef

export def Create(): void
  WindowSplit()

  enew

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=copilot_chat
  if !copilot_list_chat_buffer
    setlocal nobuflisted
  endif

  # Set buffer name
  execute 'file CopilotChat-' .. chat_count
  chat_count += 1

  # Save buffer number for reference
  g:copilot_chat_active_buffer = bufnr('%')
  b:added_syntaxes = []
  WelcomeMessage()
enddef

export def HasActiveChat(): bool
  if g:copilot_chat_active_buffer == -1
    return false
  endif

  if !bufexists(g:copilot_chat_active_buffer)
    return false
  endif

  var buf: list<dict<any>> = getbufinfo(g:copilot_chat_active_buffer)
  if empty(buf)
    return false
  endif

  return true
enddef

export def FocusActiveChat(): void
  var current_buf = bufnr('%')
  if !HasActiveChat()
    return
  endif

  if current_buf == g:copilot_chat_active_buffer
    return
  endif
  var windows = getwininfo()
  for win in range(len(windows))
    var win_info = windows[win]
    if win_info.bufnr != g:copilot_chat_active_buffer ||
	     (win_info.height == 0 && win_info.width == 0)
      continue
    endif
    # We found an active chat buffer in the current window display, so
    # switch to it.
    win_gotoid(win_getid(win_info.winnr))
    return
  endfor

  # Not found in current visible windows, so create a new split
  WindowSplit()
  execute 'buffer ' .. g:copilot_chat_active_buffer
enddef

export def ToggleActiveChat(): void
  if !HasActiveChat()
    if copilot_chat_open_on_toggle
      Create()
    endif
    return
  endif

  if bufnr('%') == g:copilot_chat_active_buffer
    close
  else
    FocusActiveChat()
  endif
enddef

export def AddInputSeparator(): void
  var width: number = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
  var separator: string = ' ' .. repeat('━', width)
  AppendMessage(separator)
  AppendMessage('')
  # required to move the cursor this way due to timing issue
  timer_start(10, (_) => cursor(line('$'), 1))
enddef

export def WaitingForResponse(): void
  AppendMessage('Waiting for response')
  #waiting_timer = timer_start(500, { -> UpdateWaitingDots()}, {'repeat': -1})
  waiting_timer = timer_start(500, function('UpdateWaitingDots'), {'repeat': -1})
enddef


def UpdateWaitingDots(timer: any): number
  if !bufexists(g:copilot_chat_active_buffer)
    timer_stop(waiting_timer)
    return 0
  endif

  var lines: list<string> = getbufline(g:copilot_chat_active_buffer, '$')
  if empty(lines)
    timer_stop(waiting_timer)
    return 0
  endif

  var current_text = lines[0]
  if current_text =~? '^Waiting for response'
      var dots = len(matchstr(current_text, '\..*$'))
      var new_dots = (dots % 3) + 1
      setbufline(g:copilot_chat_active_buffer, '$', $'Waiting for response{repeat('.', new_dots)}')
    color_index = (color_index + 1) % len(colors_gui)
    execute 'highlight CopilotWaiting guifg=' .. colors_gui[color_index] .. ' ctermfg=' .. colors_cterm[color_index]
  endif
  return 1
enddef

export def AddSelection(): void
  if !HasActiveChat()
    if !g:copilot_chat_create_on_add_selection
      return
    endif
    # TODO: copilot_chat#buffer#create should take an argument to
    # indicate if it should make the new buffer active or not.
    Create()
    execute winnr() .. ' wincmd w'
  endif

  # Save the current register and selection type
  var save_reg: string = @"
  var save_regtype: string = getregtype('"')
  var filetype: string = &filetype

  # Get the visual selection
  normal! gv"xy

  # Get the content of the visual selection
  var selection: string = getreg('x')

  # Restore the original register and selection type
  setreg('"', save_reg, save_regtype)
  AppendMessage('```' .. filetype)
  AppendMessage(split(selection, "\n"))
  AppendMessage('```')

  # Goto to the active chat buffer, either old or newly created.
  if g:copilot_chat_jump_to_chat_on_add_selection == 1
    FocusActiveChat()
  endif
enddef

export def AppendMessage(message: any): void
  appendbufline(g:copilot_chat_active_buffer, '$', message)
enddef

export def WelcomeMessage(): void
  appendbufline(g:copilot_chat_active_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  AddInputSeparator()
enddef

export def SetActive(buf: any): void
  var safe_buf = str2nr(buf)
  if safe_buf == 0
    safe_buf = bufnr('%')
  endif

  if g:copilot_chat_active_buffer == safe_buf
    return
  endif

  var bufinfo = getbufinfo(safe_buf)
  if empty(bufinfo)
    echom 'Invlid buffer number'
    return
  endif

  # Check if the buffer is valid
  if getbufvar(safe_buf, '&filetype') !=# 'copilot_chat'
    echom 'Buffer is not a Copilot Chat buffer'
    return
  endif

  g:copilot_chat_active_buffer = safe_buf
enddef

export def OnDelete(bufnr_string: string): void
  var bufnr: number = str2nr(bufnr_string)
  if g:copilot_chat_zombie_buffer != -1
    var bufinfo = getbufinfo(g:copilot_chat_zombie_buffer)
    if !empty(bufinfo) # Check if the buffer wasn't wiped out by the user
      execute 'bwipeout' .. g:copilot_chat_zombie_buffer
    endif
    g:copilot_chat_zombie_buffer = -1
  endif

  if g:copilot_chat_active_buffer != bufnr
    return
  endif
  # Unset the active chat buffer
  g:copilot_chat_zombie_buffer = g:copilot_chat_active_buffer
  g:copilot_chat_active_buffer = -1
enddef

export def Resize(): void
  if g:copilot_chat_active_buffer == -1
    return
  endif
  var current_tab = tabpagenr()

  for tabnr in range(1, tabpagenr('$'))
    exec 'normal!' tabnr .. 'gt'
    var current_window = winnr()

    for winnr in range(1, winnr('$'))
      exec $':{winnr} wincmd w'
      if &filetype !=# 'copilot_chat'
        continue
      endif
      var width: number = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
      exec ':%s/^ ━\+/ ' .. repeat('━', width) .. '/ge'
      exec ':%s/^ ━\+/ ' .. repeat('━', width) .. '/ge'
      setpos('.', getcurpos())
    endfor

    #exec ':' .tabpagenr() . winnr() .. 'wincmd w'
    exec ':' .. current_window .. ' wincmd w'
  endfor

  exec 'normal! ' .. current_tab .. 'gt'
enddef

export def ApplyCodeBlockSyntax(): void
  # Debounce syntax highlighting to avoid excessive recalculations
  if syntax_timer != -1
    timer_stop(syntax_timer)
  endif
  syntax_timer = timer_start(g:copilot_chat_syntax_debounce_ms, function('ApplyCodeBlockSyntaxImpl'))
enddef

def ApplyCodeBlockSyntaxImpl(opt: any): void
  syntax_timer = -1

  var lines: list<string> = getline(1, '$')
  var in_code_block: bool = false
  var current_lang: string = ''
  var start_line: number = 0
  var block_count: number = 0

  for linenum in range(len(lines))
    var line: string = lines[linenum]

    if !in_code_block && line =~# '^```\s*\([a-zA-Z0-9_+-]\+\)$'
      in_code_block = true
      current_lang = matchstr(line, '^```\s*\zs[a-zA-Z0-9_+-]\+\ze$')
      start_line = linenum + 1  # Start on next line

    elseif in_code_block && line =~# '^```\s*$'
      var end_line: number = linenum

      if start_line < end_line
        HighlightCodeBlock(start_line, end_line, current_lang, block_count)
        block_count += 1
      endif

      in_code_block = false
      current_lang = ''
    endif
  endfor
  redraw
enddef

def HighlightCodeBlock(start_line: number, end_line: number, lang_arg: string, block_id: number): void
  var lang: string = lang_arg
  if lang ==# 'js'
    lang = 'javascript'
  elseif lang ==# 'ts'
    lang = 'typescript'
  elseif lang ==# 'py'
    lang = 'python'
  endif

  var syntax_file: string = findfile('syntax/' .. lang .. '.vim', &runtimepath)
  if !syntax_file->empty()
    if index(b:added_syntaxes, '@' .. lang) == -1
      if exists('b:current_syntax')
        unlet b:current_syntax
      endif
      execute $'syntax include @{lang} syntax/{lang}.vim'

      add(b:added_syntaxes, '@' .. lang)
    endif
    # Define syntax region for this specific code block
    var cmd: string = $'syntax region CopilotCode_{lang}_{block_id}'
    cmd ..= ' start=/\%' .. (start_line + 1) .. 'l/'
    cmd ..= ' end=/\%' .. (end_line + 1) .. 'l/'
    cmd ..= ' contains=@' .. lang
    execute cmd
  endif
enddef

export def CheckForMacro(): void
  var current_line: string = getline('.')
  var cursor_pos: number = col('.')
  var before_cursor: string = strpart(current_line, 0, cursor_pos)
  if current_line =~# '/tab all'
    # Get the position where the pattern starts
    var pattern_start: number = match(before_cursor, '/tab all')

    # Delete the pattern
    cursor(line('.'), pattern_start + 1)
    exec 'normal! d' .. len('/tab all') .. 'l'

    # Generate list of tabs with #file: prefix, excluding current buffer
    var tab_list: list<string> = []
    for i in range(1, tabpagenr('$'))
      var buffers: list<number> = tabpagebuflist(i)
      for buf in buffers
        var filename: string = bufname(buf)
        # Only add if it's not the current buffer and has a filename
        if filename !=# '' && filename !~# 'CopilotChat'
          # Use the relative path format instead of just the base filename
          add(tab_list, $'#file: {filename}')
        endif
      endfor
      #let winnr = tabpagewinnr(i)
      #let buf_nr = buflist[winnr - 1]
      #let filename = bufname(buf_nr)

    endfor

    # Insert the tab list at cursor position, one per line
    if len(tab_list) > 0
      # Add a newline at the end of the text to be inserted
      var tabs_text: string = join(tab_list, "\n") .. "\n"
      exec 'normal! i' .. tabs_text
    else
      exec "normal! iNo other tabs found\n"
    endif

    # Position cursor on the empty line
    cursor(line('.'), 1)
  elseif current_line =~# '#file: '
    if completion_active == 1 && !pumvisible()
      completion_active = 0
    endif
    if completion_active == 0
      # TODO: should be resetting this after we do this
      # let saved_completeopt = &completeopt
      # timer_start(0, {-> execute('let &completeopt = "' . saved_completeopt . '"')})
      set completeopt=menu,menuone,noinsert,noselect
      var line: string = getline('.')
      var start: number = match(line, '#file: ') + 6
      var typed: string = strpart(line, start, col('.') - start - 1)
      if typed !=# '' && filereadable(typed) && !isdirectory(typed)
        return
      endif

      # Cache file list to avoid repeated git/glob calls
      var current_time: number = localtime()
      var cache_expired: bool = file_list_cache_time == 0 || (current_time - file_list_cache_time) > g:copilot_chat_file_cache_timeout
      if empty(file_list_cache) || cache_expired
        system('git rev-parse --is-inside-work-tree 2>/dev/null')

        if v:shell_error == 0  # We are in a git repo
          file_list_cache = systemlist('git ls-files --cached --others --exclude-standard')
        else
          file_list_cache = glob('**/*', 0, 1)
        endif
        file_list_cache_time = current_time
      endif

      # Filter out directories and prepare completion items
      var matches: list<string> = []
      for file in file_list_cache
        if !isdirectory(file) && file =~? typed
          add(matches, file)
        endif
      endfor

      # Show the completion menu
      complete(start + 1, matches)
      completion_active = 1
    endif
  endif
enddef
