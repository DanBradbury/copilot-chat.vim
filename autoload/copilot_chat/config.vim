vim9script
scriptencoding utf-8

# Generic configuration functionality
# -----------------------------------
var chat_config_file = g:copilot_chat_data_dir .. '/config.json'

# Read the config file on load
var config = {}
if filereadable(chat_config_file)
  var config_raw_data = join(readfile(chat_config_file), "\n")
  config = json_decode(config_raw_data)
endif

export def CreateDataDir()
  if !isdirectory(g:copilot_chat_data_dir)
    mkdir(g:copilot_chat_data_dir, 'p')
  endif
enddef

def SaveConfigFile()
  CreateDataDir()
  writefile([json_encode(config)], chat_config_file)
enddef

export def GetValue(key: string, default: any): any
  return get(config, key, default)
enddef

export def SetValue(key: string, value: any)
  config[key] = value
  SaveConfigFile()
enddef

export def View()
  execute 'vsplit ' .. chat_config_file
enddef
