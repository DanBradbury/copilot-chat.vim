vim9script

setlocal wrap nonumber norelativenumber nobreakindent

if exists('g:copilot_chat_disable_mappings') && g:copilot_chat_disable_mappings == 1
  finish
endif

nnoremap <buffer> <leader>cs :CopilotChatSubmit<CR>
nnoremap <buffer> <CR> :CopilotChatSubmit<CR>
