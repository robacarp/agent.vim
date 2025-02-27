function! agent#claude#set_api_key(key)
  let g:claude_api_key = a:key
  " Save the API key to a file for persistence
  let s:api_key_file = expand('~/.vim/claude-api-key')
  call writefile([a:key], s:api_key_file)
  echo "Claude API key set"
endfunction

function! agent#claude#set_model(model)
  let g:claude_model = a:model
  echo "Claude model set to: " . a:model
endfunction

function! agent#claude#request(prompt)
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
        \ 'max_tokens': 2500,
        \ 'messages': [{'role': 'user', 'content': a:prompt}],
        \ 'temperature': g:claude_temperature
        \ }

  let json_str = json_encode(json_data)
  call agent#log('claude', 'request', json_str)

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
      echoerr "Response JSON: " . response_json
      return ''
    endif
  catch
    echoerr "Error parsing Claude API response: " . v:exception
    echoerr "Response JSON: " . response_json
    return ''
  endtry
endfunction
