vim9script
scriptencoding utf-8

import autoload 'copilot_chat/api.vim' as api
import autoload 'copilot_chat/auth.vim' as auth
import autoload 'copilot_chat/config.vim' as config

var popup_selection = 0
var model_key: string = 'model'
var default_model: string = 'gpt-5.6-luna'
var model_load_timer: number = -1
var model_load_attempts: number = 0
var model_load_retry_limit: number = 60
var model_load_retry_ms: number = 500

export def FilterModels(winid: number, key: string): number
  if empty(g:copilot_chat_available_models)
    echom 'No Copilot models available'
    popup_close(winid)
    return 1
  endif

  if key ==? 'j' || key ==? "\<Down>"
    popup_selection = (popup_selection + 1) % len(g:copilot_chat_available_models)
  elseif key ==? 'k' || key ==? "\<Up>"
    popup_selection = (popup_selection - 1 + len(g:copilot_chat_available_models)) % len(g:copilot_chat_available_models)
  elseif key ==? "\<CR>" || key ==? "\<Space>"
    var selected_model: string = g:copilot_chat_available_models[popup_selection]
    config.SetValue(model_key, selected_model)
    echo selected_model .. ' set as active model'
    popup_close(winid)
    # called by name to avoid an import cycle with buffer.vim
    copilot_chat#buffer#UpdateStatusLine()
    return 1
  elseif key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    return 1
  endif

  var active_model_index = index(g:copilot_chat_available_models, Current())
  if active_model_index == -1
    active_model_index = popup_selection
  endif
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

def OpenPopup(): void
  popup_selection = index(g:copilot_chat_available_models, Current())
  if popup_selection == -1
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

def RetryOpenPopup(timer: number): void
  if !empty(g:copilot_chat_available_models)
    model_load_timer = -1
    model_load_attempts = 0
    OpenPopup()
    return
  endif

  if model_load_attempts >= model_load_retry_limit
    model_load_timer = -1
    model_load_attempts = 0
    echom 'No Copilot models available'
    return
  endif

  model_load_attempts += 1
  model_load_timer = timer_start(model_load_retry_ms, RetryOpenPopup)
enddef

export def Select(): void
  if empty(g:copilot_chat_available_models)
    if model_load_timer == -1
      echom 'Loading Copilot models...'
      model_load_attempts = 0
      auth.GetTokens()
      model_load_timer = timer_start(model_load_retry_ms, RetryOpenPopup)
    endif
    return
  endif

  if model_load_timer != -1
    timer_stop(model_load_timer)
    model_load_timer = -1
    model_load_attempts = 0
  endif

  OpenPopup()
enddef

# Cost in premium requests of a single interaction with the given model.
export def Multiplier(model: string): float
  var value: any = get(g:copilot_chat_model_multipliers, model, 1)
  if type(value) == v:t_float
    return value
  endif
  return str2float(string(value))
enddef

export def Current(): string
  var configured: string = config.GetValue(model_key, '')
  if !empty(configured)
    return configured
  endif

  if !empty(g:copilot_chat_available_models)
    return g:copilot_chat_available_models[0]
  endif

  return default_model
enddef

# Models are served by different APIs: classic chat models use
# /chat/completions, newer reasoning models (luna, sol, terra, codex) are only
# exposed through the /responses API.
export def Endpoint(model: string): string
  var endpoints: list<any> = get(g:copilot_chat_model_endpoints, model, [])

  if index(endpoints, '/chat/completions') != -1
    return '/chat/completions'
  endif

  if index(endpoints, '/responses') != -1
    return '/responses'
  endif

  return '/chat/completions'
enddef

export def Resolve(): string
  var current: string = Current()
  if empty(g:copilot_chat_available_models)
    return current
  endif

  if index(g:copilot_chat_available_models, current) != -1
    return current
  endif

  var fallback: string = g:copilot_chat_available_models[0]
  echom $'Model "{current}" is not available; using "{fallback}"'
  return fallback
enddef
