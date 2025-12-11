vim9script

if exists('*copilot_chat#models#Current') | delfunction copilot_chat#models#Current | endif

def Current()
  return 'gpt-40'
enddef
