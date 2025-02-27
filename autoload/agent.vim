function! s:create_response_buffer()
  let bufname = 'AgentResponse'

  let bufnum = bufnr(bufname)

  if bufnr(bufname) != -1
    call deletebufline(bufnum, 1, '$')
    let winid = bufwinid(bufnum)
    if l:winid != -1
      call win_gotoid(l:winid)
    else
      exec 'vsplit ' . bufname
    endif
  else
    exec 'vnew ' . bufname
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
  endif

  return bufnr('%')
endfunction


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
  let response = agent#claude#request(content)

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
  let user_prompt = input('Ask your agent: ')
  redraw!

  if empty(user_prompt)
    echo "Abort."
    return
  endif

  echo "Querying Agent..."

  " let response = agent#claude#request(s:build_json_request(user_prompt, a:code))
  let response = agent#claude#request(s:build_request(user_prompt, a:code))

  if empty(response)
    return
  endif

  let buf = s:create_response_buffer()
  call setbufline(buf, 1, split(response, "\n"))

  echo "Agent response received"
endfunction

function! agent#send_buffer_with_prompt()
  let code = join(getline(1, '$'), "\n")
  call s:send_to_agent(l:code)
endfunction

function! agent#send_selection_with_prompt() range
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

  let code = join(lines, "\n")

  call s:send_to_agent(l:code)
endfunction

function! agent#log(agent, type, message)
  if ! exists('g:agent_logging_enabled') || ! g:agent_logging_enabled
    return
  endif

  let log_dir = expand('~/.vim')
  let log_file = log_dir . '/agent-interactions.log'

  " Create directory if it doesn't exist
  if !isdirectory(log_dir)
    call mkdir(log_dir, 'p')
  endif

  " Format the log entry with timestamp
  let timestamp = strftime('%Y-%m-%d %H:%M:%S')
  let log_entry = "=== " . timestamp . " ===\n"
  let log_entry .= "Agent: " . a:agent . "\n"
  let log_entry .= a:type . ":\n" . a:message . "\n"
  let log_entry .= "----------------------------------------\n\n"

  " Append to log file
  call writefile(split(log_entry, "\n"), log_file, "a")
endfunction

function! s:build_json_request(request, code)
  let request_data = {
        \ 'code': a:code,
        \ 'prompt': a:request
        \ }

  let request = "Please be a helpful software engineering pair programmer.  You will be given a code snippet and a prompt about it. The input will be a json object with up to two fields: 'code' and 'prompt'.  The output should be a json object with up to two fields: 'updated_code' and 'response'.  Updates to the code should be sent in diff format.  If no changes are needed, no updated_code field is needed.  The response should be an answer to the prompt or, if no prompt is given, a natural language explanation of the code provided.\n\n"
  let request .= "\n\n```"
  let request .= json_encode(l:request_data)
  let request .= "```\n\n"

  return l:request
endfunction

function! s:build_request(request, code)
  let request = "Please be a helpful software engineering pair programmer.  You will be given a code snippet and a prompt about it. Please also include a suffix which shows how many tokens were sent."
  let request .= "\n\nRequest: \n"
  let request .= a:request
  let request .= "\n\nCode: \n```"
  let request .= a:code
  let request .= "```\n\n"

  return l:request
endfunction

function! s:parse_explanation(response)
  let response_json = json_decode(a:response)

  if has_key(response_json, 'response')
    let explanation = response_json['response']
    echo "Explanation: " . explanation
  endif
endfunction

function! s:parse_code(response)
  let response_json = json_decode(a:response)

  if has_key(response_json, 'updated_code')
    let updated_code = response_json['updated_code']
    echo "Updated Code: " . updated_code
  endif
endfunction
