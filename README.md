<div align="center">

# Copilot Chat for Vim

[![Vint](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/lint.yml/badge.svg)](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/lint.yml) [![Test](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/test.yml/badge.svg)](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/test.yml)

Copilot Chat functionality without having to leave Vim.

Nvim folks will be able to use [CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim) for a similar experience.

![copilotChat](https://github.com/user-attachments/assets/0cd1119d-89c8-4633-972e-641718e6b24b)
</div>

## Requirements

- [Vim](https://github.com/vim/vim)
- [NerdFonts](https://www.nerdfonts.com) (Optional for pretty icons)

## Installation

Using [Vundle](https://github.com/VundleVim/Vundle.vim), [Pathogen](https://github.com/tpope/vim-pathogen) [vim-plug](https://github.com/junegunn/vim-plug), Vim 8+ packages, or any other plugin manager.

### vundle

Add into `.vimrc` configuration.
```vim
call vundle#begin()
Plugin 'DanBradbury/copilot-chat.vim'
call vundle#end()

filetype plugin indent on
```

### Pathogen

Clone repository.
```bash
git clone https://github.com/DanBradbury/copilot-chat.vim.git ~/.vim/bundle
```

Add into `.vimrc` configuration.
```vim
call pathogen#infect()
syntax on
filetype plugin indent on
```

### vim-plug

Add into `.vimrc` configuration.
```vim
call plug#begin()
Plug 'DanBradbury/copilot-chat.vim'
call plug#end()

filetype plugin indent on
```

### Vim 8+ packages
Clone repository.
```bash
git clone https://github.com/DanBradbury/copilot-chat.vim.git ~/.vim/pack/plugins/start
```

Add into `.vimrc` configuration.
```vim
filetype plugin indent on
```

## Setup
1. Run `:CopilotChatOpen` to open a chat window. You will be prompted to setup your device on first use.
2. Write your prompt under the line separator and press `<Enter>` in normal mode.
3. You should see a `Waiting for response..` in the buffer to indicate work is being done in the background.
4. 🎉🎉🎉

## Commands
| Command | Description |
| ------- | ----------- |
| `:CopilotChat <input>` | Launches a new Copilot chat with your input as the initial prompt |
| `:CopilotChatOpen` | Opens a new Copilot chat window (default vsplit right) |
| `:CopilotChatFocus` | Focuses the currently active chat window |
| `:CopilotChatReset` | Resets the current chat window |
| `:CopilotChatConfig` | Open `config.json` for default settings when opening a new CopilotChat window |
| `:CopilotChatModels` | View available models / select active model |
| `:CopilotChatSave <name>?` | Save chat history (uses timestamp if no name provided) |
| `:CopilotChatLoad <name>?` | Load chat history (shows list of saved histories if no name provided) |
| `:CopilotChatList` | List all saved chat histories |
| `:CopilotChatSetActive <bufnr>?` | Sets the active chat window to the buffer number provided (default is the current buffer) |

## Plugin Keys
| Key | Description |
| ------- | ----------- |
| `<Plug>CopilotChatAddSelection` | Copies selected text into active char buffer |

## Default Key Mappings
| Location | Insert | Normal | Visual | Action |
| ---- | ---- | ---- | ---- | ---- |
| Chat window| - | `<CR>` | - | Submit current prompt |
| Models selection popup | - | `<CR>` | `<Space>` | - | Select the model on the current line for future chat use |

## User Key mappings
The plugin avoids adding any default vim key mappings to prevent conflict with
other plugins and the users' own mappings.

However, to easily work with the Copilot Chat plugin, the user might want to
setup his own vim key mappings. See example configuration below:

```vim
" Open a new Cpilot Chat window
nnoremap <leader>cc :CopilotChatOpen<CR>

" Add visual selection to copilot window
vmap <leader>a <Plug>CopilotChatAddSelection
```
## Features

### Autocomplete Macros

The plugin includes autocomplete macros, specifically designed to enhance productivity when working with file references.

#### `/tab all` Macro
![macros](https://github.com/user-attachments/assets/07c737e9-79f1-45e1-aa49-2729484b0e95)

- Typing `/tab all` in the chat window will automatically expand into a list of all open tabs (excluding the current buffer) with their filenames prefixed by `#file:`.
- The filenames are displayed in their relative path format, making it easier to reference files in your project.
- If no other tabs are found, the message `No other tabs found` will be inserted instead.

#### `#file:` Macro
![filemacro](https://github.com/user-attachments/assets/f790f1a0-5cdf-4660-b602-349de5c229bc)

- When typing `#file:` in the chat window, the plugin provides an autocomplete menu for file paths.
- The autocomplete intelligently suggests files based on:
  - Files tracked in the current Git repository (if inside a Git project).
  - All files in the current working directory (if not in a Git project).
- The suggestions exclude directories and only include files that match the text typed after `#file:`.
- Example:
  - Typing `#file:src/` will show a list of files in the `src/` directory.
  - Selecting a file from the menu will insert its full path.

### Model Selection
`:CopilotChatModels` brings up a popup menu for of all the available models for you to choose from. Press `<Enter>` or `<Space>` to select the highlighted model. New chats will use the selected model.

### Add Selection to Chat
By default, this is configured to `<Leader>a` when in visual mode.
- Adds the selection to the active chat window inside of a `&filetype` named codeblock
![](https://private-user-images.githubusercontent.com/2555073/423367966-e1aac0e2-0e95-4fdb-81d1-b92bb4b7cbf7.gif?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDIxOTg4MTIsIm5iZiI6MTc0MjE5ODUxMiwicGF0aCI6Ii8yNTU1MDczLzQyMzM2Nzk2Ni1lMWFhYzBlMi0wZTk1LTRmZGItODFkMS1iOTJiYjRiN2NiZjcuZ2lmP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI1MDMxNyUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNTAzMTdUMDgwMTUyWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9MjUyMTlmNDAxMjYyNzc5MjcwNmVlNTUwMDY2N2Q0NGVlMzY5OGUyM2U1MjgxMmQzOGI5ZTEwZDg2OGMzNzJkYiZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QifQ.hckZ7Swx9wszWWgdduqTRnwtrqvUPMVhqSyoSdwTny4)

### Chat History
Save and restore your chat conversations with Copilot:

#### Saving Chat History
- Use `:CopilotChatSave <name>` to save the current chat history
- If no name is provided, a timestamp will be used automatically
- History files are stored in `~/.vim/copilot-chat/history/` as JSON files

#### Loading Chat History
- Use `:CopilotChatLoad <name>` to load a previously saved chat
- If no name is provided, a list of available chat histories will be shown
- You can also view all saved histories with `:CopilotChatList`

### Prompt Templates
Copilot Chat supports custom prompt templates that can be quickly accessed during chat sessions. Templates allow you to save frequently used prompts and invoke them with a simple syntax.

#### Using Prompts
- In the chat window, start a line with `> PROMPT_NAME`
- The `PROMPT_NAME` will be automatically replaced with the template content before sending to Copilot
- Example: `> explain` would expand to the full explanation template

#### Managing Prompts
1. Open the config with `:CopilotChatConfig`
2. Add prompts to the `prompts` object in `config.json`:
```json
{
  "model": "gpt-4",
  "prompts": {
    "explain": "Explain how this code works in detail:",
    "refactor": "Suggest improvements and refactoring for this code:",
    "docs": "Generate documentation for this code:"
  }
}
```

#### Example Usage
```
> explain

function validateUser() {
  // code to validate
}
```
This will send the full template text + your code to Copilot.

## Problems

The following error message means the logged in account does not
have CoPilot activated:

> Resource not accessible by integration

## Contributing
Please see the [contribution guide](./CONTRIBUTING.md) for more information.
