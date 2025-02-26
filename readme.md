# agent.vim

A Vim plugin for interacting with AI Agents directly from your editor.

## Features

- Send text selections to Claude and get responses in a new buffer
- Configure Claude model, temperature, and token limits
- Simple key mappings for quick interaction

## Requirements

- Vim 8.0+ or Neovim
- curl
- A Claude API key from Anthropic

## Installation

Using vim-plug:

```vim
Plug 'robacarp/agent.vim'
```

After installation, set your Claude API key:

```vim
:ClaudeSetApiKey your_api_key_here
```

## Configuration

Add these settings to your vimrc:

```vim
" Required: Your Claude API key
let g:claude_api_key = 'your_api_key_here'

" Optional: Change the Claude model (default: claude-3-7-sonnet-20250219)
let g:claude_model = 'claude-3-7-sonnet-20250219'

" Optional: Set the maximum tokens in the response (default: 1000)
let g:claude_max_tokens = 1000

" Optional: Adjust temperature (default: 0.7)
let g:claude_temperature = 0.7

" Optional: Disable default key mappings
let g:claude_no_mappings = 1
```

## Usage

1. Select text in visual mode or place cursor on a line in normal mode
2. Press `<Leader>ca` (or your custom mapping)
3. A new buffer will open with Claude's response

## Commands

- `:ClaudeAsk` - Send selected text to Claude
- `:ClaudeSetModel {model}` - Change the Claude model
- `:ClaudeSetApiKey {key}` - Set your Claude API key

## Custom Mappings

```vim
" Examples of custom mappings
nmap <Leader>c <Plug>(claude-ask)
vmap <Leader>c <Plug>(claude-ask)
```

### Asking Questions About Code

You can ask specific questions about your code:

1. Select the code you want to ask about
2. Press `<Leader>cq` (or use the command `:ClaudeAskQuestion`)
3. You'll be prompted to enter your question
4. Claude will analyze the code and answer your question in a new buffer

Example questions:
- "What does this function do?"
- "How can I optimize this code?"
- "What are potential bugs in this implementation?"
- "How would I add feature X to this code?"

## License

MIT License
