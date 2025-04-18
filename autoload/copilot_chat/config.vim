let s:config_dir = expand('~/.vim/copilot-chat')
let s:chat_config_file = s:config_dir . '/config.json'

syntax match SelectedText  /^> .*/
hi! SelectedText ctermfg=46 guifg=#33FF33
hi! GreenHighlight ctermfg=green ctermbg=NONE guifg=#33ff33 guibg=NONE
hi! PopupNormal ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE

" not sure why setting this to script level doesn't work.. assume being used by the internal functions is the cause
let g:selected_index = 0

function! copilot_chat#config#load() abort
  if !isdirectory(s:config_dir)
    call mkdir(s:config_dir, 'p')
  endif
  if filereadable(s:chat_config_file)
    let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
    let g:copilot_chat_default_model = l:config.model
    let s:prompts = l:config.prompts
  else
    let l:config = {'model': g:copilot_chat_default_model, 'prompts': '[]'}
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

function! MenuKeyFilter(winid, key) abort
  if a:key ==? 'j' || a:key ==? "\<Down>"
    let g:selected_index = (g:selected_index + 1) % len(g:available_models)
  elseif a:key ==? 'k' || a:key ==? "\<Up>"
    let g:selected_index = (g:selected_index - 1 + len(g:available_models)) % len(g:available_models)
  elseif a:key ==? "\<CR>" || a:key ==? "\<Space>"
    let l:selected_model = g:available_models[g:selected_index]
    let g:copilot_chat_default_model = l:selected_model
    echo 'You selected: ' . l:selected_model
    call popup_close(a:winid)
    return 1
  elseif a:key ==? "\<Esc>" || a:key ==? 'q'
    echo 'Menu closed without selection'
    call popup_close(a:winid)
    return 1
  endif

  let l:display_items = copy(g:available_models)
  let l:active_model_index = index(g:available_models, g:copilot_chat_default_model)
  let l:display_items[l:active_model_index] = '* ' . l:display_items[l:active_model_index]
  let l:display_items[g:selected_index] = '> ' . l:display_items[g:selected_index]

  call popup_settext(a:winid, l:display_items)

	let l:bufnr = winbufnr(a:winid)
  call prop_add(g:selected_index+1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
  return 1
endfunction

function! copilot_chat#config#view_models() abort
  let g:selected_index = index(g:available_models, g:copilot_chat_default_model)
  if g:selected_index ==? -1
    let g:selected_index = 0
  endif

  let l:display_items = copy(g:available_models)
  let l:display_items[g:selected_index] = '> ' . l:display_items[g:selected_index]

  let l:options = {
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'borderhighlight': ['DiffAdd'],
        \ 'highlight': 'PopupNormal',
        \ 'padding': [1, 1, 1, 1],
        \ 'pos': 'center',
        \ 'minwidth': 50,
        \ 'filter': 'MenuKeyFilter',
        \ 'mapping': 0,
        \ 'title': 'Select Active Model'
        \ }

  let l:popup_id = popup_create(l:display_items, l:options)

	let l:bufnr = winbufnr(l:popup_id)
  call prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': l:bufnr})
  call prop_add(g:selected_index+1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
endfunction

function! copilot_chat#config#select_model() abort
  let l:selected_model = getline('.')
  let g:copilot_chat_default_model = l:selected_model
  let l:config = json_decode(join(readfile(s:chat_config_file), "\n"))
  let l:config.model = l:selected_model
  call writefile([json_encode(l:config)], s:chat_config_file)
endfunction

" vim:set ft=vim sw=2 sts=2 et:
