vim9script
scriptencoding utf-8

var debug_buffer = -1

export def WriteDebug(message: string)
  # Create the debug buffer if it doesn't exist
  if debug_buffer == -1 || !bufexists(debug_buffer)
    debug_buffer = bufadd('[Copilot Debug]')
    call bufload(debug_buffer)
    setlocal buftype=nofile bufhidden=hide noswapfile
  endif

  # Append the debug message to the buffer
  #call setbufline(debug_buffer, '$', message)
  appendbufline(debug_buffer, '$', message)

  # Optionally, open the debug buffer in a split window
  if !win_findbuf(debug_buffer)
    execute 'botright split'
    execute 'buffer ' .. debug_buffer
  endif
enddef

