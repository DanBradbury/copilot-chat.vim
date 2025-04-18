setlocal wrap nonumber norelativenumber

if exists('g:copilot_chat_disable_mappings') && g:copilot_chat_disable_mappings == 1
  finish
endif

nnoremap <buffer> <leader>cs :CopilotSubmit<CR>
nnoremap <buffer> <CR> :CopilotSubmit<CR>

" vim:set ft=vim sw=2 sts=2 et:
