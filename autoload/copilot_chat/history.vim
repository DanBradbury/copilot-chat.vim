scriptencoding utf-8

let s:history_dir = expand('~/.vim/copilot-chat/history')

function! copilot_chat#history#save(name) abort
  if !isdirectory(s:history_dir)
    call mkdir(s:history_dir, 'p')
  endif

  " Default to current date/time if no name provided
  let l:filename = empty(a:name) ? strftime('%Y%m%d_%H%M%S') : a:name
  let l:history_file = s:history_dir . '/' . l:filename . '.json'
  
  " Get chat content
  let l:chat_content = []
  let l:in_user_message = 0
  let l:in_assistant_message = 0
  let l:current_message = {'role': '', 'content': ''}
  
  for line in getbufline(g:active_chat_buffer, 1, '$')
    " Skip welcome message and waiting lines
    if line =~? '^Welcome to Copilot Chat' || line =~? '^Waiting for response'
      continue
    endif
    
    " Detect separator lines
    if line =~? ' ━\+$'
      if !empty(l:current_message.content) && !empty(l:current_message.role)
        call add(l:chat_content, l:current_message)
        let l:current_message = {'role': '', 'content': ''}
      endif
      
      " Toggle between user and assistant messages
      if l:in_user_message
        let l:in_user_message = 0
        let l:in_assistant_message = 1
        let l:current_message.role = 'assistant'
      else
        let l:in_user_message = 1
        let l:in_assistant_message = 0
        let l:current_message.role = 'user'
      endif
      continue
    endif
    
    " Add content to current message if we're in a message
    if l:in_user_message || l:in_assistant_message
      " Skip empty lines at the start of messages
      if empty(l:current_message.content) && empty(line)
        continue
      endif
      let l:current_message.content .= (empty(l:current_message.content) ? '' : "\n") . line
    endif
  endfor
  
  " Add the last message if it exists
  if !empty(l:current_message.content) && !empty(l:current_message.role)
    call add(l:chat_content, l:current_message)
  endif
  
  " Save as JSON file
  call writefile([json_encode(l:chat_content)], l:history_file)
  echo 'Chat history saved to ' . l:history_file
  return l:filename
endfunction

function! copilot_chat#history#load(name) abort
  if !isdirectory(s:history_dir)
    call mkdir(s:history_dir, 'p')
    echo 'No chat history found'
    return 0
  endif
  
  " If no name provided, show available histories
  if empty(a:name)
    call copilot_chat#history#list()
    return 0
  endif
  
  let l:history_file = s:history_dir . '/' . a:name . '.json'
  
  if !filereadable(l:history_file)
    echo 'Chat history "' . a:name . '" not found'
    return 0
  endif
  
  " Load the history file
  let l:chat_content = json_decode(join(readfile(l:history_file), "\n"))
  
  " Create a new chat buffer
  call copilot_chat#open_chat()
  
  " Add all messages to the buffer
  let l:first_message = 1
  for message in l:chat_content
    if l:first_message
      let l:first_message = 0
    else
      let l:width = winwidth(0) - 2
      let l:separator = ' ' . repeat('━', l:width)
      call appendbufline(g:active_chat_buffer, '$', l:separator)
    endif
    
    call appendbufline(g:active_chat_buffer, '$', split(message.content, "\n"))
  endfor
  
  " Add final separator for new input
  call copilot_chat#buffer#add_input_separator()
  echo 'Loaded chat history: ' . a:name
  normal! G
  return 1
endfunction

function! copilot_chat#history#list() abort
  if !isdirectory(s:history_dir)
    call mkdir(s:history_dir, 'p')
    echo 'No saved chat histories'
    return []
  endif
  
  let l:files = glob(s:history_dir . '/*.json', 0, 1)
  let l:histories = []
  
  if empty(l:files)
    echo 'No saved chat histories'
    return []
  endif
  
  echo 'Available chat histories:'
  for file in l:files
    let l:basename = fnamemodify(file, ':t:r')
    call add(l:histories, l:basename)
    echo '- ' . l:basename
  endfor
  
  return l:histories
endfunction