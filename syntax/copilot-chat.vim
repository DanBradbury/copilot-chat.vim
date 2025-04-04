syntax match CopilotWelcome /^Welcome to Copilot Chat!.*$/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorIcon /^/
syntax match CopilotSeparatorLine / ━\+$/
syntax match CopilotWaiting /Waiting for response\.*$/
syntax match CopilotPrompt /^> .*/

highlight CopilotWaiting ctermfg=46 guifg=#33FF33
highlight CopilotWelcome ctermfg=205 guifg=#ff69b4
highlight CopilotSeparatorIcon ctermfg=45 guifg=#00d7ff
highlight CopilotSeparatorLine ctermfg=205 guifg=#ff69b4
highlight CopilotPrompt ctermfg=230 guifg=#FFFF33

if !exists('g:syntax_on')
  syntax enable
endif