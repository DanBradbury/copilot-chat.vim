scriptencoding utf-8

let g:copilot_popup_selection = 0 " XXX: not sure why this doesnt work as a script var
let s:available_models = copilot_chat#api#fetch_models(copilot_chat#auth#verify_signin())
let s:model_key = 'model'

function! copilot_chat#models#filter_models(winid, key) abort
  if a:key ==? 'j' || a:key ==? "\<Down>"
    let g:copilot_popup_selection = (g:copilot_popup_selection + 1) % len(s:available_models)
  elseif a:key ==? 'k' || a:key ==? "\<Up>"
    let g:copilot_popup_selection = (g:copilot_popup_selection - 1 + len(s:available_models)) % len(s:available_models)
  elseif a:key ==? "\<CR>" || a:key ==? "\<Space>"
    let l:selected_model = s:available_models[g:copilot_popup_selection]
    call copilot_chat#config#set_value(s:model_key, l:selected_model)
    echo l:selected_model . ' set as active model'
    if has('nvim')
      call nvim_win_close(a:winid, v:true)
    else
      call popup_close(a:winid)
    endif
    return 1
  elseif a:key ==? "\<Esc>" || a:key ==? 'q'
    if has('nvim')
      call nvim_win_close(a:winid, v:true)
    else
      call popup_close(a:winid)
    endif
    return 1
  endif

  let l:display_items = copy(s:available_models)
  let l:active_model_index = index(s:available_models, copilot_chat#models#current())
  let l:display_items[l:active_model_index] = '* ' . l:display_items[l:active_model_index]
  let l:display_items[g:copilot_popup_selection] = '> ' . l:display_items[g:copilot_popup_selection]

  let l:bufnr = winbufnr(a:winid)
  if has('nvim')
    call nvim_buf_set_lines(l:bufnr, 0, -1, v:true, l:display_items)
  else
    call popup_settext(a:winid, l:display_items)

    call prop_add(g:copilot_popup_selection + 1, 1, {
          \ 'type': 'highlight',
          \ 'length': 60,
          \ 'bufnr': l:bufnr
          \ })
  endif
  return 1
endfunction

function! copilot_chat#models#select() abort
  let g:copilot_popup_selection = index(s:available_models, copilot_chat#models#current())
  if g:copilot_popup_selection ==? -1
    let g:copilot_popup_selection = 0
  endif

  let l:display_items = copy(s:available_models)
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
        \ 'filter': 'copilot_chat#models#filter_models',
        \ 'mapping': 0,
        \ 'title': 'Select Active Model'
        \ }

  if has('nvim')
    let l:bufnr = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(l:bufnr, 0, -1, v:true, l:display_items)

    let l:win_opts = {
          \ 'relative': 'editor',
          \ 'width': 50,
          \ 'height': len(l:display_items),
          \ 'col': (winwidth(0) - 50) / 2,
          \ 'row': (winheight(0) - len(l:display_items)) / 2,
          \ 'style': 'minimal',
          \ 'border': ['┌', '─' ,'┐', '│', '┘', '─', '└', '│']
          \ }
    let l:winid = nvim_open_win(l:bufnr, v:true, l:win_opts)

    call nvim_buf_set_keymap(l:bufnr, 'n', 'j', ':call copilot_chat#config#filter_models('.l:winid.', "j")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', 'k', ':call copilot_chat#config#filter_models('.l:winid.', "k")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', '<Down>', ':call copilot_chat#config#filter_models('.l:winid.', "\<lt>Down>")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', '<Up>', ':call copilot_chat#config#filter_models('.l:winid.', "\<lt>Up>")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', '<CR>', ':call copilot_chat#config#filter_models('.l:winid.', "\<lt>CR>")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', 'q', ':call copilot_chat#config#filter_models('.l:winid.', "q")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
    call nvim_buf_set_keymap(l:bufnr, 'n', '<Esc>', ':call copilot_chat#config#filter_models('.l:winid.', "\<lt>Esc>")<CR>', {'nowait': v:true, 'noremap': v:true, 'silent': v:true})
  else
    let l:popup_id = popup_create(l:display_items, l:options)

    let l:bufnr = winbufnr(l:popup_id)
    call prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': l:bufnr})
    call prop_add(g:copilot_popup_selection + 1, 1, {
          \ 'type': 'highlight',
          \ 'length': 60,
          \ 'bufnr': l:bufnr
          \ })
  endif
endfunction

let s:default_model = 'gpt-4o'
function! copilot_chat#models#current() abort
  return copilot_chat#config#get_value(s:model_key, s:default_model)
endfunction

" vim:set ft=vim sw=2 sts=2 et:
