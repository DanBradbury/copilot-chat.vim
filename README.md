<div align="center">

# Copilot Chat for Vim

[![Vint](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/lint.yml/badge.svg)](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/lint.yml) [![Test](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/test.yml/badge.svg)](https://github.com/DanBradbury/copilot-chat.vim/actions/workflows/test.yml)

Copilot Chat functionality without having to leave Vim.

Nvim folks will be able to use [CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim) for a similar experience.

![copilotChat](https://github.com/user-attachments/assets/0cd1119d-89c8-4633-972e-641718e6b24b)
</div>

## Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Setup](#setup)
- [Commands](#commands)
- [Key Mappings](#key-mappings)
- [Features](#features)
- [Custom Configuration](#custom-configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Requirements

- [Vim 9.0+](https://github.com/vim/vim)
- [Nerd Fonts](https://www.nerdfonts.com) (Optional for pretty icons)
- Active GitHub Copilot subscription

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug), [Vundle](https://github.com/VundleVim/Vundle.vim), [Pathogen](https://github.com/tpope/vim-pathogen), Vim 8+ packages, or any other plugin manager.

<details>
<summary><b>vim-plug (Recommended)</b></summary>

Add to your `.vimrc`:
```vim
call plug#begin()
Plug 'DanBradbury/copilot-chat.vim'
call plug#end()

filetype plugin indent on
```

Then run `:PlugInstall` in Vim.
</details>

<details>
<summary><b>Vundle</b></summary>

Add to your `.vimrc`:
```vim
call vundle#begin()
Plugin 'DanBradbury/copilot-chat.vim'
call vundle#end()

filetype plugin indent on
```

Then run `:PluginInstall` in Vim.
</details>

<details>
<summary><b>Pathogen</b></summary>

Clone the repository:
```bash
git clone https://github.com/DanBradbury/copilot-chat.vim.git ~/.vim/bundle/copilot-chat.vim
```

Add to your `.vimrc`:
```vim
call pathogen#infect()
syntax on
filetype plugin indent on
```
</details>

<details>
<summary><b>Vim 8+ packages</b></summary>

Clone the repository:
```bash
git clone https://github.com/DanBradbury/copilot-chat.vim.git ~/.vim/pack/plugins/start/copilot-chat.vim
```

Add to your `.vimrc`:
```vim
filetype plugin indent on
```
</details>

## Setup

1. After installing the plugin, the first time you launch Vim you'll be presented with the device registration page in your default browser
2. Follow the steps on the page and paste the Device Code when prompted
3. Once completed, press `<Enter>` back in Vim to complete the registration process
4. Start chatting with Copilot (`:CopilotChatOpen`, `:CopilotChat simple question`, etc.)
5. 🎉 You're ready to go!

## Commands

| Command | Description |
| ------- | ----------- |
| `:CopilotChat <input>` | Launch a new Copilot chat with your input as the initial prompt |
| `:CopilotChatOpen` | Open a new Copilot chat window (default: vsplit right) |
| `:CopilotChatFocus` | Focus the currently active chat window |
| `:CopilotChatReset` | Reset the current chat window |
| `:CopilotChatClose` | Close the current chat window |
| `:CopilotChatConfig` | Open `config.json` for default settings |
| `:CopilotChatModels` | View available models / select active model |
| `:CopilotChatSave [name]` | Save chat history (uses timestamp if no name provided) |
| `:CopilotChatLoad [name]` | Load chat history (shows list if no name provided) |
| `:CopilotChatList` | List all saved chat histories |
| `:CopilotChatSetActive [bufnr]` | Set the active chat window (defaults to current buffer) |
| `:CopilotChatUsage` | Show Copilot usage stats |

## Key Mappings

### Plugin Keys
| Key | Description |
| --- | ----------- |
| `<Plug>CopilotChatAddSelection` | Copy selected text into active chat buffer |

### Default Mappings (in Chat Window)
| Mode | Key | Action |
| ---- | --- | ------ |
| Normal | `<CR>` | Submit current prompt |
| Normal (Models popup) | `<CR>` or `<Space>` | Select the highlighted model |

### Example User Mappings

The plugin intentionally avoids setting global key mappings to prevent conflicts. Here are some suggested mappings for your `.vimrc`:

```vim
" Open a new Copilot Chat window
nnoremap <leader>cc :CopilotChatOpen<CR>

" Focus existing chat window
nnoremap <leader>cf :CopilotChatFocus<CR>

" Add visual selection to chat
vmap <leader>ca <Plug>CopilotChatAddSelection

" Reset chat conversation
nnoremap <leader>cr :CopilotChatReset<CR>
```

## Features

### Autocomplete Macros

#### `/tab all` Macro
![macros](https://github.com/user-attachments/assets/07c737e9-79f1-45e1-aa49-2729484b0e95)

Type `/tab all` in the chat window to automatically expand into a list of all open tabs (excluding the current buffer) with their filenames prefixed by `#file:`. If no other tabs are found, `No other tabs found` will be inserted.

#### `#file:` Macro
![filemacro](https://github.com/user-attachments/assets/f790f1a0-5cdf-4660-b602-349de5c229bc)

Type `#file:` in the chat window for intelligent file path autocomplete:
- Suggests files from the current Git repository (if in a Git project)
- Falls back to all files in the current working directory
- Excludes directories, only shows files
- Filters based on text typed after `#file:`

**Example**: Typing `#file:src/` shows files in the `src/` directory.

### Model Selection

Use `:CopilotChatModels` to open a popup menu of available models. Press `<Enter>` or `<Space>` to select. New chats will use the selected model.

### Add Selection to Chat

Visually select code and use `<Plug>CopilotChatAddSelection` (or your custom mapping) to add it to the active chat window inside a filetype-specific code block.

![Add Selection Demo](https://private-user-images.githubusercontent.com/2555073/423367966-e1aac0e2-0e95-4fdb-81d1-b92bb4b7cbf7.gif?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDIxOTg4MTIsIm5iZiI6MTc0MjE5ODUxMiwicGF0aCI6Ii8yNTU1MDczLzQyMzM2Nzk2Ni1lMWFhYzBlMi0wZTk1LTRmZGItODFkMS1iOTJiYjRiN2NiZjcuZ2lmP1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI1MDMxNyUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNTAzMTdUMDgwMTUyWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9MjUyMTlmNDAxMjYyNzc5MjcwNmVlNTUwMDY2N2Q0NGVlMzY5OGUyM2U1MjgxMmQzOGI5ZTEwZDg2OGMzNzJkYiZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QifQ.hckZ7Swx9wszWWgdduqTRnwtrqvUPMVhqSyoSdwTny4)

### Chat History

Save and restore your chat conversations:

**Saving**:
```vim
:CopilotChatSave my-refactoring-session
:CopilotChatSave  " Uses timestamp if no name provided
```

**Loading**:
```vim
:CopilotChatLoad my-refactoring-session
:CopilotChatLoad  " Shows list of available histories
:CopilotChatList  " View all saved chat histories
```

History files are stored in `~/.vim/copilot-chat/history/` as JSON files.

### Prompt Templates

Save and reuse frequently used prompts. In the chat window, start a line with `> PROMPT_NAME` to expand the template.

#### Managing Prompts

1. Open config: `:CopilotChatConfig`
2. Add prompts to `config.json`:

```json
{
  "model": "gpt-4",
  "prompts": {
    "explain": "Explain how this code works in detail:",
    "refactor": "Suggest improvements and refactoring for this code:",
    "docs": "Generate documentation for this code:",
    "test": "Write unit tests for this code:",
    "review": "Review this code for bugs and best practices:"
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

The `> explain` will be replaced with the full template text before sending to Copilot.

## Custom Configuration

Customize behavior by setting global variables in your `.vimrc`:

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `g:copilot_chat_window_position` | `'right'` | Split direction: `'right'`, `'left'`, `'top'`, `'bottom'` |
| `g:copilot_chat_disable_mappings` | `0` | Set to `1` to disable default chat window mappings |
| `g:copilot_chat_create_on_add_selection` | `1` | Create new chat when adding selection if none exists |
| `g:copilot_chat_jump_to_chat_on_add_selection` | `1` | Jump to chat window after adding selection |
| `g:copilot_reuse_active_chat` | `1` | Reuse active chat window instead of creating new ones |
| `g:copilot_chat_data_dir` | `~/.vim/copilot-chat/` | Directory for plugin data storage |
| `g:copilot_chat_open_on_toggle` | `1` | Set to `0` to prevent opening on toggle |
| `g:copilot_list_chat_buffer` | `0` | Set to `1` to list copilot-chat buffers |
| `g:copilot_chat_message_history_limit` | `20` | Maximum messages sent to API (lower = faster) |
| `g:copilot_chat_syntax_debounce_ms` | `300` | Debounce delay for syntax highlighting (ms) |
| `g:copilot_chat_file_cache_timeout` | `5` | Cache timeout for file completion (seconds) |

### Example Configurations

**Open chats in horizontal split at bottom**:
```vim
let g:copilot_chat_window_position = 'bottom'
```

**Performance tuning for long chat sessions**:
```vim
" Limit context for faster responses
let g:copilot_chat_message_history_limit = 10

" Reduce CPU usage on slower machines
let g:copilot_chat_syntax_debounce_ms = 500

" Reduce system calls for large projects
let g:copilot_chat_file_cache_timeout = 10
```

**Customize selection behavior**:
```vim
" Don't create new chat when adding selection
let g:copilot_chat_create_on_add_selection = 0

" Stay in current window after adding selection
let g:copilot_chat_jump_to_chat_on_add_selection = 0
```

## Troubleshooting

### "Resource not accessible by integration"

This error means the logged-in GitHub account does not have an active Copilot subscription. Please:
1. Verify your GitHub Copilot subscription at https://github.com/settings/copilot
2. Ensure your subscription is active and not expired
3. Try logging out and back in to refresh your credentials

### Chat window not responding

- Check if you're authenticated: Restart Vim and check for authentication prompts
- Verify network connectivity
- Try resetting the chat with `:CopilotChatReset`

### File autocomplete not working

- Ensure you're in a valid directory
- For Git projects, verify the repository is initialized
- Try adjusting `g:copilot_chat_file_cache_timeout` for better performance

## Contributing

Please see the [contribution guide](./CONTRIBUTING.md) for more information.

---

<div align="center">

**[Report Bug](https://github.com/DanBradbury/copilot-chat.vim/issues)** · **[Request Feature](https://github.com/DanBradbury/copilot-chat.vim/issues)**

</div>
