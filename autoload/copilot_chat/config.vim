scriptencoding utf-8

" Generic configuration functionality
" -----------------------------------
let s:chat_config_file = g:copilot_chat_data_dir . '/config.json'

" Read the config file on load
if filereadable(s:chat_config_file)
  let s:config_raw_data = join(readfile(s:chat_config_file), '\n')
  let s:config = json_decode(s:config_raw_data)
else
  let s:config = {}
endif

function! copilot_chat#config#create_data_dir() abort
  if !isdirectory(g:copilot_chat_data_dir)
    call mkdir(g:copilot_chat_data_dir, 'p')
  endif
endfunction

function! copilot_chat#config#save_config_file() abort
  call copilot_chat#config#create_data_dir()
  call writefile([json_encode(s:config)], s:chat_config_file)
endfunction

function! copilot_chat#config#get_value(key, default) abort
  return get(s:config, a:key, a:default)
endfunction

function! copilot_chat#config#set_value(key, value) abort
  let s:config[a:key] = a:value
  call copilot_chat#config#save_config_file()
endfunction

function! copilot_chat#config#view() abort
  execute 'vsplit ' . s:chat_config_file
endfunction

let s:mcp_servers = copilot_chat#config#get_value('mcp', {})
if s:mcp_servers != {}
  call copilot_chat#log#write('we found mcp servers to load')
  "call copilot_chat#log#write(s:mcp_servers)
  call copilot_chat#tools#load_mcp_servers(s:mcp_servers)
else
  call copilot_chat#log#write('no mcp servers found')
endif

" vim:set ft=vim sw=2 sts=2 et:
