scriptencoding utf-8

syntax match CopilotWelcome /^Welcome to Copilot Chat!.*$/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorLine / ━\+$/
syntax match CopilotWaiting /Waiting for response\.*$/
syntax match CopilotPrompt /^> .*/
syntax match CopilotFiles /^#file:.*/
syntax match CopilotMCPCall /^MCP FUNCTION CALL: .*/
syntax match CopilotMCPResponse /^MCP FUNCTION RESPONSE:.* {{{$/

syntax match CopilotCodeFence /^```\(\s*\w\+\)\?$/ contains=CopilotCodeLang
syntax match CopilotCodeLang /\w\+/ contained
syntax match CopilotCodeFenceEnd /^```$/
syntax match CopilotFoldMarker /^}}}$/

highlight CopilotWaiting ctermfg=46 guifg=#33FF33
highlight CopilotWelcome ctermfg=205 guifg=#ff69b4
highlight CopilotSeparatorIcon ctermfg=45 guifg=#00d7ff
highlight CopilotSeparatorLine ctermfg=205 guifg=#ff69b4
highlight CopilotPrompt ctermfg=230 guifg=#FFFF33
highlight CopilotCodeFence ctermfg=240 guifg=#585858
highlight CopilotCodeFenceEnd ctermfg=240 guifg=#585858
highlight CopilotCodeLang ctermfg=111 guifg=#87afff
highlight CopilotFiles ctermfg=12 guifg=#1E90FF
highlight CopilotMCPCall ctermfg=111 guifg=#87afff cterm=italic gui=italic
highlight CopilotMCPResponse ctermfg=111 guifg=#87afff cterm=italic gui=italic
highlight CopilotFoldMarker ctermfg=240 guifg=#585858

if !exists('g:syntax_on')
  syntax enable
endif

" vim:set ft=vim sw=2 sts=2 et:
