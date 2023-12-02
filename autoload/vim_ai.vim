call vim_ai_config#load()

let s:plugin_root = expand('<sfile>:p:h:h')
let s:complete_py = s:plugin_root . "/py/complete.py"
let s:chat_py = s:plugin_root . "/py/chat.py"

" remembers last command parameters to be used in AIRedoRun
let s:last_is_selection = 0
let s:last_instruction = ""
let s:last_command = ""
let s:last_config = {}

let s:scratch_buffer_name = ">>> AI chat"

" Configures ai-chat scratch window.
" - scratch_buffer_keep_open = 0
"   - opens new ai-chat every time
" - scratch_buffer_keep_open = 1
"   - opens last ai-chat buffer
"   - keeps the buffer in the buffer list
function! vim_ai#MakeScratchWindow()
  let l:keep_open = g:vim_ai_chat['ui']['scratch_buffer_keep_open']
  if l:keep_open && bufexists(s:scratch_buffer_name)
    " reuse chat buffer
    execute "buffer " . s:scratch_buffer_name
    return
  endif
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal ft=aichat
  if l:keep_open
    setlocal bufhidden=hide
  else
    setlocal bufhidden=wipe
  endif
  if bufexists(s:scratch_buffer_name)
    " spawn another window if chat already exist
    let l:index = 2
    while bufexists(s:scratch_buffer_name . " " . l:index)
      let l:index += 1
    endwhile
    execute "file " . s:scratch_buffer_name . " " . l:index
  else
    execute "file " . s:scratch_buffer_name
  endif
endfunction

function! s:MakeSelectionPrompt(selection, instruction, config)
  let l:selection = ""
  if a:instruction == ""
    let l:selection = a:selection
  elseif !empty(a:selection)
    let l:boundary = a:config['options']['selection_boundary']
    if l:boundary != "" && match(a:selection, l:boundary) == -1
      " NOTE: surround selection with boundary (e.g. #####) in order to eliminate empty responses
      let l:selection = l:boundary . "\n" . a:selection . "\n" . l:boundary
    else
      let l:selection = a:selection
    endif
  endif
  return l:selection
endfunction

function! s:MakePrompt(selection, instruction, config)
  let l:instruction = trim(a:instruction)
  let l:delimiter = l:instruction != "" && a:selection != "" ? ":\n" : ""
  let l:selection = s:MakeSelectionPrompt(a:selection, l:instruction, a:config)
  return join([l:instruction, l:delimiter, l:selection], "")
endfunction

function! s:OpenChatWindow(open_conf)
  let l:open_cmd = has_key(g:vim_ai_open_chat_presets, a:open_conf)
        \ ? g:vim_ai_open_chat_presets[a:open_conf]
        \ : a:open_conf
  execute l:open_cmd
endfunction

function! s:set_paste(config)
  if a:config['ui']['paste_mode']
    setlocal paste
  endif
endfunction

function! s:set_nopaste(config)
  if a:config['ui']['paste_mode']
    setlocal nopaste
  endif
endfunction

function! s:GetCurrentLineOrSelection(is_selection)
  if a:is_selection
    return s:GetVisualSelection()
  else
    return trim(join(getline(a:firstline, a:lastline), "\n"))
  endif
endfunction

function! s:SelectCurrentLineOrSelection(is_selection)
  if a:is_selection
    execute "normal! gv"
  else
    execute 'normal! V' 
  endif
endfunction

function! s:GetVisualSelection()
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  " The exclusive mode means that the last character of the selection area is not included in the operation scope.
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  return join(lines, "\n")
endfunction

" Complete prompt
" - is_selection - <range> parameter
" - config       - function scoped vim_ai_complete config
" - a:1          - optional instruction prompt
function! vim_ai#AIRun(is_selection, config, ...) range
  let l:config = vim_ai_config#ExtendDeep(g:vim_ai_complete, a:config)

  let l:instruction = a:0 ? a:1 : ""
  let l:selection = s:GetCurrentLineOrSelection(a:is_selection)
  let l:prompt = s:MakePrompt(l:selection, l:instruction, l:config)
  " used for getting in Python script
  let l:is_selection = a:is_selection

  let s:last_command = "complete"
  let s:last_config = a:config
  let s:last_instruction = l:instruction
  let s:last_is_selection = a:is_selection

  let l:cursor_on_empty_line = empty(getline('.'))
  call s:set_paste(l:config)
  if l:cursor_on_empty_line
    execute "normal! " . a:lastline . "GA"
  else
    execute "normal! " . a:lastline . "Go"
  endif
  execute "py3file " . s:complete_py
  execute "normal! " . a:lastline . "G"
  call s:set_nopaste(l:config)
endfunction

" Edit prompt
" - is_selection - <range> parameter
" - config       - function scoped vim_ai_edit config
" - a:1          - optional instruction prompt
function! vim_ai#AIEditRun(is_selection, config, ...) range
  let l:config = vim_ai_config#ExtendDeep(g:vim_ai_edit, a:config)

  let l:instruction = a:0 ? a:1 : ""
  let l:selection = s:GetCurrentLineOrSelection(a:is_selection)
  " used for getting in Python script
  let l:is_selection = a:is_selection
  let l:prompt = s:MakePrompt(l:selection, l:instruction, l:config)

  let s:last_command = "edit"
  let s:last_config = a:config
  let s:last_instruction = l:instruction
  let s:last_is_selection = a:is_selection

  call s:set_paste(l:config)
  call s:SelectCurrentLineOrSelection(a:is_selection)
  execute "normal! c"
  execute "py3file " . s:complete_py
  call s:set_nopaste(l:config)
endfunction

" Start and answer the chat
" - is_selection - <range> parameter
" - config       - function scoped vim_ai_chat config
" - a:1          - optional instruction prompt
function! vim_ai#AIChatRun(is_selection, config, ...) range
  let l:config = vim_ai_config#ExtendDeep(g:vim_ai_chat, a:config)

  let l:instruction = ""
  let l:selection = s:GetVisualSelection()
  " used for getting in Python script
  let l:is_selection = a:is_selection
  call s:set_paste(l:config)
  if &filetype != 'aichat'
    let l:chat_win_id = bufwinid(s:scratch_buffer_name)
    if l:chat_win_id != -1
      " TODO: look for first active chat buffer, in case .aichat file is used
      " reuse chat in active window
      call win_gotoid(l:chat_win_id)
    else
      " open new chat window
      let l:open_conf = l:config['ui']['open_chat_command']
      call s:OpenChatWindow(l:open_conf)
    endif
  endif

  let l:prompt = ""
  if a:0 || a:is_selection
    let l:instruction = a:0 ? a:1 : ""
    let l:prompt = s:MakePrompt(l:selection, l:instruction, l:config)
  endif

  let s:last_command = "chat"
  let s:last_config = a:config
  let s:last_instruction = l:instruction
  let s:last_is_selection = a:is_selection

  execute "py3file " . s:chat_py
  call s:set_nopaste(l:config)
endfunction

" Start a new chat
" a:1 - optional preset shorcut (below, right, tab)
function! vim_ai#AINewChatRun(...)
  let l:open_conf = a:0 ? "preset_" . a:1 : g:vim_ai_chat['ui']['open_chat_command']
  call s:OpenChatWindow(l:open_conf)
  call vim_ai#AIChatRun(0, {})
endfunction

" Repeat last AI command
function! vim_ai#AIRedoRun()
  execute "normal! u"
  if s:last_command == "complete"
    if s:last_is_selection
      '<,'>call vim_ai#AIRun(s:last_is_selection, s:last_config, s:last_instruction)
    else
      call vim_ai#AIRun(s:last_is_selection, s:last_config, s:last_instruction)
    endif
  endif
  if s:last_command == "edit"
    if s:last_is_selection
      '<,'>call vim_ai#AIEditRun(s:last_is_selection, s:last_config, s:last_instruction)
    else
      call vim_ai#AIEditRun(s:last_is_selection, s:last_config, s:last_instruction)
    endif
  endif
  if s:last_command == "chat"
    " chat does not need prompt, all information are in the buffer already
    call vim_ai#AIChatRun(0, s:last_config)
  endif
endfunction
