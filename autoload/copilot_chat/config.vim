let s:chat_config_file = g:copilot_chat_data_dir . '/config.json'

function! copilot_chat#config#create_data_dir() abort
  if !isdirectory(g:copilot_chat_data_dir)
    call mkdir(g:copilot_chat_data_dir, 'p')
  endif
endfunction

function! copilot_chat#config#load() abort
  call copilot_chat#config#create_data_dir()
  if filereadable(s:chat_config_file)
    let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
    let g:default_model = l:config.model
    let s:prompts = l:config.prompts
  else
    let l:config = {'model': g:default_model, 'prompts': '[]'}
    call writefile([json_encode(l:config)], s:chat_config_file)
  endif
endfunction

function! copilot_chat#config#get(key, default) abort
  let l:var_name = 'g:copilot_chat_' . a:key
  if exists(l:var_name)
    return eval(l:var_name)
  endif

  if exists('s:' . a:key)
    return eval('s:' . a:key)
  endif

  return a:default
endfunction

function! copilot_chat#config#view() abort
  execute 'vsplit ' . s:chat_config_file
endfunction

function! copilot_chat#config#view_models() abort
  vsplit
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  call appendbufline(bufnr('%'), 0, 'Available Models:')
  call appendbufline(bufnr('%'), '$', g:available_models)
  execute 'syntax match ActiveModel /^' . g:default_model . '$/'
  execute 'highlight ActiveModel guifg=#33FF33 ctermfg=46'
  nnoremap <buffer> <CR> :SelectModel<CR>
endfunction

function! copilot_chat#config#select_model() abort
  let l:selected_model = getline('.')
  let g:default_model = l:selected_model
  let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
  let l:config.model = l:selected_model
  call writefile([json_encode(l:config)], s:chat_config_file)
endfunction

" vim:set ft=vim sw=2 sts=2 et:
