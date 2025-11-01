let g:captured_messages = []
let g:captured_file_list = []

function! copilot_chat#api#fetch_models(chat_token) abort
  return []
endfunction

function! copilot_chat#api#async_request(messages, file_list) abort
  let g:captured_messages = a:messages
  let g:captured_file_list = a:file_list
  return 1
endfunction
