vim9script
scriptencoding utf-8

# Generic configuration functionality
# -----------------------------------
var chat_config_file: string = g:copilot_chat_data_dir .. '/config.json'

# Read the config file on load
var config: dict<any> = {}
if filereadable(chat_config_file)
  var config_raw_data: string = join(readfile(chat_config_file), "\n")
  config = json_decode(config_raw_data)
endif

export def CreateDataDir(): void
  if !isdirectory(g:copilot_chat_data_dir)
    mkdir(g:copilot_chat_data_dir, 'p')
  endif
enddef

def SaveConfigFile(): void
  CreateDataDir()
  writefile([json_encode(config)], chat_config_file)
enddef

export def GetValue(key: string, default: any): any
  return get(config, key, default)
enddef

export def SetValue(key: string, value: any): void
  config[key] = value
  SaveConfigFile()
enddef

export def View(): void
  execute 'vsplit ' .. chat_config_file
enddef
