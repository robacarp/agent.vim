" agent.vim - A Vim plugin for interacting with AI Agents from within vim, including Claude
" Maintainer: robacarp
" Version: 0.1

" Configuration variables with defaults
if !exists('g:claude_api_key')
  let s:api_key_file = expand('~/.vim/claude-api-key')
  if filereadable(s:api_key_file)
    let g:claude_api_key = trim(readfile(s:api_key_file)[0])
  else
    let g:claude_api_key = ''
  endif
endif

if !exists('g:claude_model')
  let g:claude_model = 'claude-3-7-sonnet-20250219'
endif

if !exists('g:claude_max_tokens')
  let g:claude_max_tokens = 1000
endif

if !exists('g:claude_temperature')
  let g:claude_temperature = 0.7
endif


" Create autocommand group for plugin
augroup agent_vim
  autocmd!

  autocmd BufNewFile,BufRead agent_response.* setlocal filetype=markdown

  command! -nargs=1 ClaudeSetModel call agent#set_claude_model(<q-args>)
  command! -nargs=1 ClaudeSetApiKey call agent#set_claude_api_key(<q-args>)
  command! -range Ai <line1>,<line2>call agent#send_selection_with_prompt()
  " command! Air call agent#send_buffer_with_prompt()
  " nnoremap <silent> <Plug>(ask-agent-question) :AskAgent<CR>
  " vnoremap <silent> <Plug>(ask-agent-question) :AskAgentRange<CR>

  " Default mappings for the new function if no_mappings is not set
  if !exists('g:agent_vim_no_mappings')
    nmap <Leader>cq :Ai<CR>
    vmap <Leader>cq :Ai<CR>
  endif
augroup END
