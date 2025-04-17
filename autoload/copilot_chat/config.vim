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


" Models configuration
" --------------------
let g:copilot_popup_selection = 0 " XXX: not sure why this doesnt work as a script var

function! copilot_chat#config#filter_models(winid, key) abort
  if a:key ==? 'j' || a:key ==? "\<Down>"
    let g:copilot_popup_selection = (g:copilot_popup_selection + 1) % len(g:copilot_chat_available_models)
  elseif a:key ==? 'k' || a:key ==? "\<Up>"
    let g:copilot_popup_selection = (g:copilot_popup_selection - 1 + len(g:copilot_chat_available_models)) % len(g:copilot_chat_available_models)
  elseif a:key ==? "\<CR>" || a:key ==? "\<Space>"
    let l:selected_model = g:copilot_chat_available_models[g:copilot_popup_selection]
    call copilot_chat#config#set_value('model', l:selected_model)
    echo l:selected_model . ' set as active model'
    call popup_close(a:winid)
    return 1
  elseif a:key ==? "\<Esc>" || a:key ==? 'q'
    call popup_close(a:winid)
    return 1
  endif

  let l:display_items = copy(g:copilot_chat_available_models)
  let l:active_model_index = index(g:copilot_chat_available_models, copilot_chat#config#model())
  let l:display_items[l:active_model_index] = '* ' . l:display_items[l:active_model_index]
  let l:display_items[g:copilot_popup_selection] = '> ' . l:display_items[g:copilot_popup_selection]

  call popup_settext(a:winid, l:display_items)

	let l:bufnr = winbufnr(a:winid)
  call prop_add(g:copilot_popup_selection + 1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
  return 1
endfunction

function! copilot_chat#config#view_models() abort
  if len(g:copilot_chat_available_models) == 0
    call copilot_chat#api#fetch_models(copilot_chat#auth#verify_signin())
  endif

  let g:copilot_popup_selection = index(g:copilot_chat_available_models, copilot_chat#config#model())
  if g:copilot_popup_selection ==? -1
    let g:copilot_popup_selection = 0
  endif

  let l:display_items = copy(g:copilot_chat_available_models)
  let l:display_items[g:copilot_popup_selection] = '> ' . l:display_items[g:copilot_popup_selection]

  execute 'syntax match SelectedText  /^> .*/'
  execute 'hi! SelectedText ctermfg=46 guifg=#33FF33'
  execute 'hi! GreenHighlight ctermfg=green ctermbg=NONE guifg=#33ff33 guibg=NONE'
  execute 'hi! PopupNormal ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE'

  let l:options = {
        \ 'border': [1, 1, 1, 1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'borderhighlight': ['DiffAdd'],
        \ 'highlight': 'PopupNormal',
        \ 'padding': [1, 1, 1, 1],
        \ 'pos': 'center',
        \ 'minwidth': 50,
        \ 'filter': 'copilot_chat#config#filter_models',
        \ 'mapping': 0,
        \ 'title': 'Select Active Model'
        \ }

  let l:popup_id = popup_create(l:display_items, l:options)

	let l:bufnr = winbufnr(l:popup_id)
  call prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': l:bufnr})
  call prop_add(g:copilot_popup_selection + 1, 1, {
        \ 'type': 'highlight',
        \ 'length': 60,
        \ 'bufnr': l:bufnr
        \ })
endfunction

let s:default_model = 'gpt-4o'
function! copilot_chat#config#model() abort
  return get(s:config, 'model', s:default_model)
endfunction

" vim:set ft=vim sw=2 sts=2 et:
