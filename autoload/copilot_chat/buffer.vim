vim9script
scriptencoding utf-8

import autoload 'copilot_chat/config.vim' as config

var colors_gui = ['#33FF33', '#4DFF33', '#66FF33', '#80FF33', '#99FF33', '#B3FF33', '#CCFF33', '#E6FF33', '#FFFF33']
var colors_cterm = [46, 118, 154, 190, 226, 227, 228, 229, 230]
var color_index = 0
var chat_count = 1
var completion_active = 0
var syntax_timer = -1
var file_completion_timer = -1
var file_list_cache: list<string> = []
var file_list_cache_time = 0
var copilot_list_chat_buffer = get(g:, 'copilot_list_chat_buffer', 0)
var copilot_chat_open_on_toggle = get(g:, 'copilot_chat_open_on_toggle', 1)
var waiting_timer = 0

def WindowSplit()
  var position = config.GetValue('window_position', 'right')
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

export def Create(): any
  WindowSplit()

  enew

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=copilot_chat
  if copilot_list_chat_buffer == 0
    setlocal nobuflisted
  endif

  # Set buffer name
  execute 'file CopilotChat-' .. chat_count
  chat_count += 1

  # Save buffer number for reference
  g:copilot_chat_active_buffer = bufnr('%')
  b:added_syntaxes = []
  WelcomeMessage()
  return g:copilot_chat_active_buffer
enddef

export def HasActiveChat(): number
  if g:copilot_chat_active_buffer == -1
    return 0
  endif

  if !bufexists(g:copilot_chat_active_buffer)
    return 0
  endif

  var buf = getbufinfo(g:copilot_chat_active_buffer)
  if empty(buf)
    return 0
  endif

  return 1
enddef

export def FocusActiveChat()
  var current_buf = bufnr('%')
  if copilot_chat#buffer#has_active_chat() == 0
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
    execute win_info.winnr .. ' wincmd w'
    return
  endfor

  # Not found in current visible windows, so create a new split
  WindowSplit()
  execute 'buffer ' .. g:copilot_chat_active_buffer
enddef

def ToggleActiveChat(): number
  if HasActiveChat() == 0
    if copilot_chat_open_on_toggle == 1
      Create()
    endif
    return
  endif

  var current_bufnr = bufnr('%')
  if current_bufnr == g:copilot_chat_active_buffer
    close
  else
    FocusActiveChat()
  endif
enddef

export def AddInputSeparator()
  var width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
  var separator = ' ' .. repeat('━', width)
  AppendMessage(separator)
  AppendMessage('')
enddef

export def WaitingForResponse()
  AppendMessage('Waiting for response')
  #waiting_timer = timer_start(500, { -> UpdateWaitingDots()}, {'repeat': -1})
  waiting_timer = timer_start(500, function('UpdateWaitingDots'), {'repeat': -1})
enddef


def UpdateWaitingDots(timer: any): number
  if !bufexists(g:copilot_chat_active_buffer)
    timer_stop(waiting_timer)
    return 0
  endif

  var lines = getbufline(g:copilot_chat_active_buffer, '$')
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

export def AddSelection()
  if HasActiveChat() == 0
    if g:copilot_chat_create_on_add_selection == 0
      return
    endif
    # TODO: copilot_chat#buffer#create should take an argument to
    # indicate if it should make the new buffer active or not.
    var curr_win = winnr()
    Create()
    execute curr_win .. 'wincmd w'
  endif

  # Save the current register and selection type
  var save_reg = @"
  var save_regtype = getregtype('"')
  var filetype = &filetype

  # Get the visual selection
  normal! gv"xy

  # Get the content of the visual selection
  var selection = getreg('x')

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

export def AppendMessage(message: any)
  appendbufline(g:copilot_chat_active_buffer, '$', message)
enddef

export def WelcomeMessage()
  appendbufline(g:copilot_chat_active_buffer, 0, 'Welcome to Copilot Chat! Type your message below:')
  AddInputSeparator()
enddef

export def SetActive(bufnr: number)
  if bufnr ==# ''
    bufnr = bufnr('%')
  endif

  if g:copilot_chat_active_buffer == bufnr
    return
  endif

  var bufinfo = getbufinfo(bufnr)
  if empty(bufinfo)
    echom 'Invlid buffer number'
    return
  endif

  # Check if the buffer is valid
  if getbufvar(bufnr, '&filetype') !=# 'copilot_chat'
    echom 'Buffer is not a Copilot Chat buffer'
    return
  endif

  # Set the active chat buffer to the current buffer
  g:copilot_chat_active_buffer = bufnr
enddef

export def OnDelete(bufnr: number)
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

export def Resize()
  if g:copilot_chat_active_buffer == -1
    return
  endif

  var currtab = tabpagenr()

  for tabnr in range(1, tabpagenr('$'))
    exec 'normal!' tabnr .. 'gt'
    var currwin = winnr()

    for winnr in range(1, winnr('$'))
      exec $':{winnr}wincmd w'
      if &filetype !=# 'copilot_chat'
        continue
      endif
      var width = winwidth(0) - 2 - getwininfo(win_getid())[0].textoff
      var curpos = getcurpos()
      exec ':%s/^ ━\+/ ' .. repeat('━', width) .. '/ge'
      exec ':%s/^ ━\+/ ' .. repeat('━', width) .. '/ge'
      setpos('.', curpos)
    endfor

    exec ':' .. currwin .. 'wincmd w'
  endfor

  exec 'normal!' currtab .. 'gt'
enddef

export def ApplyCodeBlockSyntax()
  # Debounce syntax highlighting to avoid excessive recalculations
  if syntax_timer != -1
    timer_stop(syntax_timer)
  endif
  syntax_timer = timer_start(g:copilot_chat_syntax_debounce_ms, function('ApplyCodeBlockSyntaxImpl'))
enddef

def ApplyCodeBlockSyntaxImpl(opt: any)
  syntax_timer = -1

  var lines = getline(1, '$')
  var total_lines = len(lines)

  var in_code_block = 0
  var current_lang = ''
  var start_line = 0
  var block_count = 0

  for linenum in range(total_lines)
    var line = lines[linenum]

    if !in_code_block && line =~# '^```\s*\([a-zA-Z0-9_+-]\+\)$'
      in_code_block = 1
      current_lang = matchstr(line, '^```\s*\zs[a-zA-Z0-9_+-]\+\ze$')
      start_line = linenum + 1  # Start on next line

    elseif in_code_block && line =~# '^```\s*$'
      var end_line = linenum

      if start_line < end_line
        HighlightCodeBlock(start_line, end_line, current_lang, block_count)
        block_count += 1
      endif

      in_code_block = 0
      current_lang = ''
    endif
  endfor
  redraw
enddef

def HighlightCodeBlock(start_line: number, end_line: number, lang_arg: string, block_id: number)
  var lang: string = lang_arg
  if lang ==# 'js'
    lang = 'javascript'
  elseif lang ==# 'ts'
    lang = 'typescript'
  elseif lang ==# 'py'
    lang = 'python'
  endif

  var syn_group = 'CopilotCode_' .. lang .. '_' .. block_id

  var syntax_file = findfile('syntax/' .. lang .. '.vim', &runtimepath)
  if !empty(syntax_file)
    if index(b:added_syntaxes, '@' .. lang) == -1
      if exists('b:current_syntax')
        unlet b:current_syntax
      endif
      var syntaxfile = 'syntax/' .. lang .. '.vim'
      execute 'syntax include @' .. lang .. ' ' .. syntaxfile

      add(b:added_syntaxes, '@' .. lang)
    endif
    # Define syntax region for this specific code block
    var cmd = 'syntax region ' .. syn_group
    cmd ..= ' start=/\%' .. (start_line + 1) .. 'l/'
    cmd ..= ' end=/\%' .. (end_line + 1) .. 'l/'
    cmd ..= ' contains=@' .. lang
    execute cmd
  endif
enddef

export def CheckForMacro()
  var current_line: string = getline('.')
  var cursor_pos = col('.')
  var before_cursor = strpart(current_line, 0, cursor_pos)
  if current_line =~# '/tab all'
    # Get the position where the pattern starts
    var pattern_start = match(before_cursor, '/tab all')

    # Delete the pattern
    cursor(line('.'), pattern_start + 1)
    exec 'normal! d' .. len('/tab all') .. 'l'

    # Get current buffer number to exclude it
    var current_bufnr = bufnr('%')

    # Generate list of tabs with #file: prefix, excluding current buffer
    var tab_list = []
    for i in range(1, tabpagenr('$'))
      var buffers = tabpagebuflist(i)
      for buf in buffers
        var filename = bufname(buf)
        # Only add if it's not the current buffer and has a filename
        if filename !=# '' && filename !~# 'CopilotChat'
          # Use the relative path format instead of just the base filename
          var display_name = '#file: ' .. filename
          add(tab_list, display_name)
        endif
      endfor
      #let winnr = tabpagewinnr(i)
      #let buf_nr = buflist[winnr - 1]
      #let filename = bufname(buf_nr)

    endfor

    # Insert the tab list at cursor position, one per line
    if len(tab_list) > 0
      # Add a newline at the end of the text to be inserted
      var tabs_text = join(tab_list, "\n") .. "\n"
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
      var line = getline('.')
      var start = match(line, '#file: ') + 6
      var typed = strpart(line, start, col('.') - start - 1)
      if typed !=# '' && filereadable(typed) && !isdirectory(typed)
        return
      endif

      # Cache file list to avoid repeated git/glob calls
      var current_time = localtime()
      var cache_expired = file_list_cache_time == 0 || (current_time - file_list_cache_time) > g:copilot_chat_file_cache_timeout
      if empty(file_list_cache) || cache_expired
        var is_git_repo = system('git rev-parse --is-inside-work-tree 2>/dev/null')

        if v:shell_error == 0  # We are in a git repo
          file_list_cache = systemlist('git ls-files --cached --others --exclude-standard')
        else
          file_list_cache = glob('**/*', 0, 1)
        endif
        file_list_cache_time = current_time
      endif

      # Filter out directories and prepare completion items
      var matches = []
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
