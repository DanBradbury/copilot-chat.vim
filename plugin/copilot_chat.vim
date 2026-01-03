vim9script
scriptencoding utf-8

import autoload 'copilot_chat.vim' as copilot
import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/buffer.vim' as _buffer
import autoload 'copilot_chat/config.vim' as config
import autoload 'copilot_chat/history.vim' as history
import autoload 'copilot_chat/models.vim' as models
import autoload 'copilot_chat/auth.vim' as auth

if exists('g:loaded_copilot_chat')
  finish
endif
g:loaded_copilot_chat = 1

g:copilot_chat_prompts = {}
g:copilot_chat_active_buffer = -1
g:copilot_chat_data_dir = get(g:, 'copilot_chat_data_dir', expand('~/.vim/copilot-chat', 1))
g:copilot_chat_zombie_buffer = -1
g:copilot_reuse_active_chat = get(g:, 'copilot_reuse_active_chat', 0)
g:copilot_chat_create_on_add_selection = get(g:, 'copilot_chat_create_on_add_selection', 1)
g:copilot_chat_jump_to_chat_on_add_selection = get(g:, 'copilot_chat_jump_to_chat_on_add_selection', 1)
g:copilot_chat_message_history_limit = get(g:, 'copilot_chat_message_history_limit', 20)
g:copilot_chat_syntax_debounce_ms = get(g:, 'copilot_chat_syntax_debounce_ms', 300)
g:copilot_chat_file_cache_timeout = get(g:, 'copilot_chat_file_cache_timeout', 5)
g:copilot_chat_token = ''
g:copilot_chat_device_token = {}
g:copilot_chat_available_models = []

auth.VerifySignin()

command! -nargs=0 CopilotChatOpen copilot.OpenChat()
command! -nargs=1 CopilotChat copilot.StartChat(<q-args>)
command! -nargs=0 CopilotChatFocus _buffer.FocusActiveChat()
command! -nargs=0 CopilotChatSubmit copilot.SubmitMessage()
command! -nargs=0 CopilotChatConfig config.View()
command! -nargs=0 CopilotChatModels models.Select()
command! -nargs=? CopilotChatSave history.Save(<q-args>)
command! -nargs=? -complete=customlist,history.Complete CopilotChatLoad history.Load(<q-args>)
command! -nargs=0 CopilotChatList history.List()
command! -nargs=0 CopilotChatReset copilot.ResetChat()
command! -nargs=? CopilotChatSetActive _buffer.SetActive(<q-args>)
command! -nargs=0 CopilotChatToggle _buffer.ToggleActiveChat()
command! -nargs=0 CopilotChatUsage api.GetUsage()

vnoremap <silent> <Plug>CopilotChatAddSelection :<C-u>call copilot_chat#buffer#AddSelection()<CR>

#requires a wrapper for use in autocmds
def OnDeleteWrapper(a: string): void
  _buffer.OnDelete(str2nr(a))
enddef

def ApplyCodeBlockSyntaxWrapper(): void
  _buffer.ApplyCodeBlockSyntax()
enddef

def CheckForMacroWrapper(): void
  _buffer.CheckForMacro()
enddef

def ResizeWrapper(): void
  _buffer.Resize()
enddef

augroup CopilotChat
  autocmd!
  autocmd FileType copilot_chat autocmd BufDelete <buffer> _buffer.OnDelete(expand('<abuf>'))
  autocmd FileType copilot_chat autocmd BufEnter,TextChanged,TextChangedI <buffer> _buffer.ApplyCodeBlockSyntax()
  autocmd FileType copilot_chat autocmd TextChangedI <buffer> _buffer.CheckForMacro()
  if has('patch-9.0.0917')
    autocmd VimResized,WinResized * _buffer.Resize()
  else
    autocmd VimResized * _buffer.Resize()
  endif
augroup END
