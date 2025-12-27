vim9script
scriptencoding utf-8

syntax match CopilotWelcome /^Welcome to Copilot Chat!.*$/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorLine / ━\+$/
syntax match CopilotWaiting /Waiting for response\.*$/
syntax match CopilotPrompt /^> .*/
syntax match CopilotFiles /^#file:.*/
syntax match CopilotToolCall /^TOOL-CALL.*/

syntax match CopilotCodeFence /^```\(\s*\w\+\)\?$/ contains=CopilotCodeLang
syntax match CopilotCodeLang /\w\+/ contained
syntax match CopilotCodeFenceEnd /^```$/

highlight CopilotWaiting ctermfg=46 guifg=#33FF33
highlight CopilotWelcome ctermfg=205 guifg=#ff69b4
highlight CopilotSeparatorIcon ctermfg=45 guifg=#00d7ff
highlight CopilotSeparatorLine ctermfg=205 guifg=#ff69b4
highlight CopilotPrompt ctermfg=230 guifg=#FFFF33
highlight CopilotCodeFence ctermfg=240 guifg=#585858
highlight CopilotCodeFenceEnd ctermfg=240 guifg=#585858
highlight CopilotCodeLang ctermfg=111 guifg=#87afff
highlight CopilotFiles ctermfg=12 guifg=#1E90FF
highlight CopilotToolCall guibg=#ff69b4

if !exists('g:syntax_on')
  syntax enable
endif
