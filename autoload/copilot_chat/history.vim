vim9script
scriptencoding utf-8

import autoload 'copilot_chat.vim' as base
import autoload 'copilot_chat/buffer.vim' as _buffer

var history_dir: string = expand('~/.vim/copilot-chat/history', 1)

export def Save(name: string): string
  if !isdirectory(history_dir)
    mkdir(history_dir, 'p')
  endif

  # Default to current date/time if no name provided
  var filename: string = empty(name) ? strftime('%Y%m%d_%H%M%S') : name
  var history_file = history_dir .. '/' .. filename .. '.json'

  # Get chat content
  var chat_content: list<dict<any>> = []
  var in_user_message: number = 0
  var in_assistant_message: number = 0
  var current_message: dict<any> = {'role': '', 'content': ''}

  for line in getbufline(g:copilot_chat_active_buffer, 1, '$')
    # Skip welcome message and waiting lines
    if line =~? '^Welcome to Copilot Chat' || line =~? '^Waiting for response'
      continue
    endif

    # Detect separator lines
    if line =~? ' ━\+$'
      if !empty(current_message.content) && !empty(current_message.role)
        add(chat_content, current_message)
        current_message = {'role': '', 'content': ''}
      endif

      # Toggle between user and assistant messages
      if in_user_message
        in_user_message = 0
        in_assistant_message = 1
        current_message.role = 'assistant'
      else
        in_user_message = 1
        in_assistant_message = 0
        current_message.role = 'user'
      endif
      continue
    endif

    # Add content to current message if we're in a message
    if in_user_message || in_assistant_message
      # Skip empty lines at the start of messages
      if empty(current_message.content) && empty(line)
        continue
      endif
      current_message.content ..= (empty(current_message.content) ? '' : "\n") .. line
    endif
  endfor

  # Add the last message if it exists
  if !empty(current_message.content) && !empty(current_message.role)
    add(chat_content, current_message)
  endif

  # Save as JSON file
  writefile([json_encode(chat_content)], history_file)
  echo 'Chat history saved to ' .. history_file
  return filename
enddef

export def Load(name: string): number
  if !isdirectory(history_dir)
    mkdir(history_dir, 'p')
    echo 'No chat history found'
    return 0
  endif

  if empty(name)
    List()
    return 0
  endif

  var history_file = history_dir .. '/' .. name .. '.json'

  if !filereadable(history_file)
    echo 'Chat history "' .. name .. '" not found'
    return 0
  endif

  var chat_content: list<dict<any>> = json_decode(join(readfile(history_file), "\n"))

  base.OpenChat()

  var first_message: bool = true
  for message in chat_content
    if first_message
      first_message = false
    else
      var width: number = winwidth(0) - 2
      var separator: string = ' ' .. repeat('━', width)
      appendbufline(g:copilot_chat_active_buffer, '$', separator)
    endif

    appendbufline(g:copilot_chat_active_buffer, '$', split(message.content, "\n"))
  endfor

  _buffer.AddInputSeparator()
  return 1
enddef

export def Get(): list<string>
  if !isdirectory(history_dir)
    mkdir(history_dir, 'p')
    return []
  endif

  return map(glob(history_dir .. '/*.json', 0, 1), 'fnamemodify(v:val, ":t:r")')
enddef

export def Complete(arg_lead: string, cmd_line: any, cursor_pos: number): list<string>
  #return matchfuzzy(Get(), arg_lead)
  return matchfuzzy(copilot_chat#history#get(), arg_lead)
enddef

export def List(): void
  var histories = Get()

  if empty(histories)
    echom 'No saved chat histories'
    return
  endif

  echo 'Available chat historie '
  for history in histories
    echom '- ' .. history
  endfor
enddef
