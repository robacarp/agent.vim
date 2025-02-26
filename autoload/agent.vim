" agent.vim - Autoload functions for claude-in-vim plugin
" Maintainer: You
" Version: 0.1

" Set API key
function! agent#set_claude_api_key(key)
  let g:claude_api_key = a:key
  " Save the API key to a file for persistence
  let s:api_key_file = expand('~/.vim/claude-api-key')
  call writefile([a:key], s:api_key_file)
  echo "Claude API key set"
endfunction

" Set model
function! agent#set_claude_model(model)
  let g:claude_model = a:model
  echo "Claude model set to: " . a:model
endfunction

function! s:create_response_buffer()
  let bufname = 'AgentResponse'

  " Check if buffer already exists
  let bufnum = bufnr(bufname)

  if bufnum != -1
    " Buffer exists, clear it and reuse
    call deletebufline(bufnum, 1, '$')
    exe 'buffer ' . bufnum
  else
    " Create new buffer
    exe 'new ' . bufname
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
  endif

  return bufnr('%')
endfunction

" Make API request to Claude
function! s:request_claude(prompt)
  if empty(g:claude_api_key)
    echoerr "Error: Claude API key not set. Use :ClaudeSetApiKey to set it."
    return ''
  endif

  " Create a temporary file for the response
  " Use Vim's tempname() function to get a valid temp file path
  let temp_file = tempname()
  
  " Prepare the JSON payload
  let json_data = {
        \ 'model': g:claude_model,
        \ 'messages': [{'role': 'user', 'content': a:prompt}],
        \ 'max_tokens': g:claude_max_tokens,
        \ 'temperature': g:claude_temperature
        \ }
  
  let json_str = json_encode(json_data)
  
  " Build the curl command with proper escaping
  let cmd = 'curl -s -X POST https://api.anthropic.com/v1/messages'
  let cmd .= ' -H "Content-Type: application/json"'
  let cmd .= ' -H "x-api-key: ' . g:claude_api_key . '"'
  let cmd .= ' -H "anthropic-version: 2023-06-01"'
  
  " Write JSON to a temporary file instead of inline in the command
  let json_file = tempname()
  call writefile([json_str], json_file)
  let cmd .= ' -d @' . shellescape(json_file)
  let cmd .= ' > ' . shellescape(temp_file)

  " Execute the curl command
  let output = system(cmd)
  
  " Clean up the JSON temp file
  call delete(json_file)
  
  " Check for errors
  if v:shell_error != 0
    echoerr "Error making request to Claude API: " . output
    call delete(temp_file)
    return ''
  endif

  " Read the response from the temp file
  if filereadable(temp_file)
    let response_json = join(readfile(temp_file), "\n")
    call delete(temp_file)
  else
    echoerr "Error: Could not read response file"
    return ''
  endif
  
  try
    let response_data = json_decode(response_json)
    if has_key(response_data, 'content') && len(response_data.content) > 0
      return response_data.content[0].text
    else
      echoerr "Error: Unexpected response format from Claude API"
      return ''
    endif
  catch
    echoerr "Error parsing Claude API response: " . v:exception
    return ''
  endtry
endfunction

" Main function to ask Claude
function! agent#ask() range
  " Get selected text in visual mode or current line in normal mode
  if visualmode() !=# ''
    let content = s:get_visual_selection()
  else
    let content = getline(a:firstline, a:lastline)
    let content = join(content, "\n")
  endif

  echo "Asking Agent..."
  
  " Get response from Claude
  let response = s:request_claude(content)
  
  if empty(response)
    return
  endif
  
  " Create a new buffer and display the response
  let buf = s:create_response_buffer()
  call setbufline(buf, 1, split(response, "\n"))
  
  echo "Claude response received"
endfunction

" Helper function to get visual selection
function! s:get_visual_selection()
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  
  if len(lines) == 0
    return ''
  endif
  
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  
  return join(lines, "\n")
endfunction

function! s:send_to_agent(code)
  " Add a global variable to toggle logging (default: disabled)
  if !exists('g:agent_logging_enabled')
    let g:agent_logging_enabled = 0
  endif

  " Prompt for a question
  let question = input('Ask your agent: ')

  if empty(question)
    echo "Question was empty, cancelling request."
    return
  endif

  " Format prompt with both the question and code
  let prompt = "Question: " . question . "\n\nCode:\n```\n" . a:code . "\n```\n\nPlease analyze the code and answer my question."
  redraw!
  echo "Asking Agent..."

  " Get response from Claude
  let response = s:request_claude(prompt)

  if empty(response)
    return
  endif

  " Log the interaction if logging is enabled
  if g:agent_logging_enabled
    call s:log_interaction(question, response)
  endif

  " Create a new buffer and display the response
  let buf = s:create_response_buffer()
  call setbufline(buf, 1, split(response, "\n"))

  echo "Agent response received"
endfunction

function! agent#send_buffer_with_prompt()
  let code = join(getline(1, '$'), "\n")
  call s:send_to_agent(l:code)
endfunction

function! agent#send_code_with_prompt() range
  let code = ''
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)

  " Adjust the first and last line if we're in visual block mode
  if mode() ==# "\<C-v>"
    let lines = map(lines, 'v:val[column_start-1:column_end-1]')
  elseif mode() ==# 'v'
    " In character-wise visual mode, adjust first and last line
    if line_start == line_end
      let lines[0] = lines[0][column_start-1:column_end-1]
    else
      let lines[0] = lines[0][column_start-1:]
      let lines[-1] = lines[-1][:column_end-1]
    endif
  endif
  " Visual line mode doesn't need adjustment

  let code = join(lines, "\n")

  call s:send_to_agent(l:code)
endfunction

function! s:log_interaction(question, response)
  let log_dir = expand('~/.vim')
  let log_file = log_dir . '/claude-interactions.log'

  " Create directory if it doesn't exist
  if !isdirectory(log_dir)
    call mkdir(log_dir, 'p')
  endif
  
  " Format the log entry with timestamp
  let timestamp = strftime('%Y-%m-%d %H:%M:%S')
  let log_entry = "=== " . timestamp . " ===\n"
  let log_entry .= "Question: " . a:question . "\n\n"
  let log_entry .= "Response:\n" . a:response . "\n\n"
  let log_entry .= "----------------------------------------\n\n"
  
  " Append to log file
  call writefile(split(log_entry, "\n"), log_file, "a")
endfunction
