vim9script

import autoload 'copilot_chat/buffer.vim' as _buffer
import autoload 'copilot_chat/agent.vim' as agent
import autoload 'copilot_chat/api.vim' as api

export def List(): list<any>
  return [
    {
      "name": "apply_patch",
      "description": 'Edit text files. Do not use this tool to edit Jupyter notebooks. `apply_patch` allows you to execute a diff/patch against a text file, but the format of the diff specification is unique to this task, so pay careful attention to these instructions. To use the `apply_patch` command, you should pass a message of the following structure as \"input\":\n\n*** Begin Patch\n[YOUR_PATCH]\n*** End Patch\n\nWhere [YOUR_PATCH] is the actual content of your patch, specified in the following V4A diff format.\n\n*** [ACTION] File: [/absolute/path/to/file] -> ACTION can be one of Add, Update, or Delete.\nAn example of a message that you might pass as \"input\" to this function, in order to apply a patch, is shown below.\n\n*** Begin Patch\n*** Update File: /Users/someone/pygorithm/searching/binary_search.py\n@@class BaseClass\n@@    def search():\n-        pass\n+        raise NotImplementedError()\n\n@@class Subclass\n@@    def search():\n-        pass\n+        raise NotImplementedError()\n\n*** End Patch\nDo not use line numbers in this diff format.',
      "parameters": {
          "type": "object",
          "properties": {
              "input": {
                  "type": "string",
                  "description": "The edit patch to apply."
              },
              "explanation": {
                  "type": "string",
                  "description": "A short description of what the tool call is aiming to achieve."
              }
          },
          "required": [
              "input",
              "explanation"
          ]
      },
      "type": "function",
      "strict": false
    },
    {
      "name": "create_directory",
      "description": "Create a new directory structure in the workspace. Will recursively create all directories in the path, like mkdir -p. You do not need to use this tool before using create_file, that tool will automatically create the needed directories.",
      "parameters": {
        "type": "object",
        "properties": {
          "dirPath": {
            "type": "string",
            "description": "The absolute path to the directory to create."
          }
        },
        "required": [
          "dirPath"
        ]
      },
      "type": "function",
      "strict": false
    },
    {
      "name": "create_file",
      "description": "This is a tool for creating a new file in the workspace. The file will be created with the specified content. The directory will be created if it does not already exist. Never use this tool to edit a file that already exists.",
      "parameters": {
        "type": "object",
        "properties": {
          "filePath": {
            "type": "string",
            "description": "The absolute path to the file to create."
          },
          "content": {
            "type": "string",
            "description": "The content to write to the file."
          }
        },
        "required": [
          "filePath",
          "content"
        ]
      },
      "type": "function",
      "strict": false
    },
    {
      "name": "read_file",
      "description": "Read the contents of a file.\n\nYou must specify the line range you're interested in. Line numbers are 1-indexed. If the file contents returned are insufficient for your task, you may call this tool again to retrieve more content. Prefer reading larger ranges over doing many small reads.",
      "parameters": {
        "type": "object",
        "properties": {
          "filePath": {
            "description": "The absolute path of the file to read.",
            "type": "string"
          },
          "startLine": {
            "type": "number",
            "description": "The line number to start reading from, 1-based."
          },
          "endLine": {
            "type": "number",
            "description": "The inclusive line number to end reading at, 1-based."
          }
        },
        "required": [
          "filePath",
          "startLine",
          "endLine"
        ]
      },
      "type": "function",
      "strict": false
    }
  ]
enddef

export def InvokeTool(outcome: dict<any>, buffer_messages: list<any>): void
  var function_name = outcome['name']
  var args = outcome['arguments']

  var call_id = outcome['call_id']
  var function_call = {
    'type': 'function_call',
    'name': 'read_file',
    'arguments': args,
    'call_id': call_id
  }
  add(buffer_messages, function_call)
  _buffer.AppendMessage($'TOOL-CALL: {function_name} ({call_id})')

  if function_name == 'apply_patch'
    add(buffer_messages, {
      'type': 'function_call_output',
      'call_id': call_id,
      'output': agent.ApplyPatch(outcome)
    })
    api.AgentRequest(buffer_messages)

  elseif function_name == 'create_file'
    agent.CreateFile(outcome)
  elseif function_name == 'create_directory'
    agent.CreateDirectory(outcome)
  elseif function_name == 'read_file'
    add(buffer_messages, {
      'type': 'function_call_output',
      'call_id': call_id,
      'output': agent.ReadFile(outcome)
    })
    api.AgentRequest(buffer_messages)
  else
    echom $'unsupoorted function call {function_name}'
  endif
enddef
