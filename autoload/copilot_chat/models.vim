vim9script
scriptencoding utf-8

import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/config.vim' as config

g:copilot_popup_selection = 0 # XXX: not sure why this doesnt work as a script var
var model_key: string = 'model'
var default_model: string = 'gpt-4o'
var available_models: list<string> = api.FetchModels(auth.VerifySignin())

export def FilterModels(winid: number, key: string): number
  if key ==? 'j' || key ==? "\<Down>"
    g:copilot_popup_selection = (g:copilot_popup_selection + 1) % len(available_models)
  elseif key ==? 'k' || key ==? "\<Up>"
    g:copilot_popup_selection = (g:copilot_popup_selection - 1 + len(available_models)) % len(available_models)
  elseif key ==? "\<CR>" || key ==? "\<Space>"
    var selected_model: string = available_models[g:copilot_popup_selection]
    config.SetValue(model_key, selected_model)
    echo selected_model .. ' set as active model'
    popup_close(winid)
    return 1
  elseif key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    return 1
  endif

  var display_items: list<string> = copy(available_models)
  var active_model_index = index(available_models, Current())
  display_items[active_model_index] = '* ' .. display_items[active_model_index]
  display_items[g:copilot_popup_selection] = '> ' .. display_items[g:copilot_popup_selection]

  popup_settext(winid, display_items)

  prop_add(g:copilot_popup_selection + 1, 1, {
    'type': 'highlight',
    'length': 60,
    'bufnr': winbufnr(winid)
  })
  return 1
enddef

export def Select()
  g:copilot_popup_selection = index(available_models, Current())
  if g:copilot_popup_selection ==? -1
    g:copilot_popup_selection = 0
  endif

  var display_items = copy(available_models)
  display_items[g:copilot_popup_selection] = '> ' .. display_items[g:copilot_popup_selection]

  execute 'syntax match SelectedText  /^ > .*/'
  execute 'hi! SelectedText ctermfg = 46 guifg=#33FF33'
  execute 'hi! GreenHighlight ctermfg = green ctermbg=NONE guifg=#33ff33 guibg=NONE'
  execute 'hi! PopupNormal ctermfg = NONE ctermbg=NONE guifg=NONE guibg=NONE'

  var options = {
    'border': [1, 1, 1, 1],
    'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    'borderhighlight': ['DiffAdd'],
    'highlight': 'PopupNormal',
    'padding': [1, 1, 1, 1],
    'pos': 'center',
    'minwidth': 50,
    'filter': FilterModels,
    'mapping': 0,
    'title': 'Select Active Model'
  }

  var popup_id = popup_create(display_items, options)

  var bufnr = winbufnr(popup_id)
  prop_type_add('highlight', {'highlight': 'GreenHighlight', 'bufnr': bufnr})
  prop_add(g:copilot_popup_selection + 1, 1, {
    'type': 'highlight',
    'length': 60,
    'bufnr': bufnr
  })
enddef

export def Current(): string
  return config.GetValue(model_key, default_model)
enddef
