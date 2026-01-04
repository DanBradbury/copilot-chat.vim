vim9script
scriptencoding utf-8

import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/config.vim' as config

var popup_selection = 0
var model_key: string = 'model'
var default_model: string = 'gpt-4o'

export def FilterModels(winid: number, key: string): number
  if key ==? 'j' || key ==? "\<Down>"
    popup_selection = (popup_selection + 1) % len(g:copilot_chat_available_models)
  elseif key ==? 'k' || key ==? "\<Up>"
    popup_selection = (popup_selection - 1 + len(g:copilot_chat_available_models)) % len(g:copilot_chat_available_models)
  elseif key ==? "\<CR>" || key ==? "\<Space>"
    var selected_model: string = g:copilot_chat_available_models[popup_selection]
    config.SetValue(model_key, selected_model)
    echo selected_model .. ' set as active model'
    popup_close(winid)
    return 1
  elseif key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    return 1
  endif

  var active_model_index = index(g:copilot_chat_available_models, Current())
  var display_items: list<string> = map(copy(g:copilot_chat_available_models), 'v:val .. " (x" .. g:copilot_chat_model_multipliers[v:val] .. ")"')
  display_items[active_model_index] = '* ' .. display_items[active_model_index]
  display_items[popup_selection] = '> ' .. display_items[popup_selection]

  popup_settext(winid, display_items)

  prop_add(popup_selection + 1, 1, {
    'type': 'highlight',
    'length': 60,
    'bufnr': winbufnr(winid)
  })
  return 1
enddef

export def Select(): void
  popup_selection = index(g:copilot_chat_available_models, Current())
  if popup_selection ==? -1
    popup_selection = 0
  endif

  var display_items: list<string> = map(copy(g:copilot_chat_available_models), 'v:val .. " (x" .. g:copilot_chat_model_multipliers[v:val] .. ")"')
  display_items[popup_selection] = '> ' .. display_items[popup_selection]

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
  prop_add(popup_selection + 1, 1, {
    'type': 'highlight',
    'length': 60,
    'bufnr': bufnr
  })
enddef

export def Current(): string
  return config.GetValue(model_key, default_model)
enddef
