scriptencoding utf-8

let g:copilot_chat_prompts = {}
let g:copilot_chat_active_buffer = -1
let g:copilot_chat_default_model = 'gpt-4o'
let g:copilot_chat_available_models = []
let g:copilot_chat_data_dir = get(g:, 'copilot_chat_data_dir', expand('~/.vim/copilot-chat', 1))
let g:copilot_chat_zombie_buffer = -1
let g:copilot_reuse_active_chat = get(g:, 'copilot_reuse_active_chat', 0)
let g:copilot_chat_create_on_add_selection = get(g:,'copilot_chat_create_on_add_selection', 1)
let g:copilot_chat_jump_to_chat_on_add_selection = get(g:, 'copilot_chat_jump_to_chat_on_add_selection', 1)

command! -nargs=0 CopilotChatOpen call copilot_chat#open_chat()
command! -nargs=1 CopilotChat call copilot_chat#start_chat(<q-args>)
command! -nargs=0 CopilotChatFocus call copilot_chat#buffer#focus_active_chat()
command! -nargs=0 CopilotSubmit call copilot_chat#submit_message()
command! -nargs=0 CopilotChatConfig call copilot_chat#config#view()
command! -nargs=0 CopilotChatModels call copilot_chat#config#view_models()
command! -nargs=0 CopilotChatSelectModel call copilot_chat#config#select_model()
command! -nargs=? CopilotChatSave call copilot_chat#history#save(<q-args>)
command! -nargs=? -complete=customlist,copilot_chat#history#complete CopilotChatLoad call copilot_chat#history#load(<q-args>)
command! -nargs=0 CopilotChatList call copilot_chat#history#list()
command! -nargs=0 CopilotChatReset call copilot_chat#reset_chat()
command! -nargs=? CopilotChatSetActive call copilot_chat#buffer#set_active(<q-args>)

vnoremap <silent> <Plug>CopilotChatAddSelection :<C-u>call copilot_chat#buffer#add_selection()<CR>

augroup CopilotChat
  autocmd!
  autocmd FileType copilot_chat autocmd BufDelete <buffer> call copilot_chat#buffer#on_delete(expand('<abuf>'))
augroup END

" vim:set ft=vim sw=2 sts=2 et:
