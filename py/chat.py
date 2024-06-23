import vim

import traceback


# import utils
plugin_root = vim.eval("s:plugin_root")
vim.command(f"py3file {plugin_root}/py/utils.py")
vim.command(f"py3file {plugin_root}/py/backends.py")

# chat_options = parse_chat_header_options()
# options = {**config_options, **chat_options}
# openai_options = make_openai_options(options)
# http_options = make_http_options(options)


def get_messages():
    # initial_prompt = '\n'.join(options.get('initial_prompt', []))
    # initial_messages = parse_chat_messages(initial_prompt)

    chat_content = vim.eval('trim(join(getline(1, "$"), "\n"))')
    chat_messages = parse_chat_messages(chat_content)
    # messages = initial_messages + chat_messages
    return chat_messages


prompt, role = parse_prompt_and_role(vim.eval("l:prompt"))
initialize_chat_window()
messages = get_messages()

try:
    if messages[-1]["content"].strip():
        is_selection = vim.eval("l:is_selection")
        backend = LoremIpsumBackend()

        vim.command("normal! Go\n<<< assistant\n\n")
        vim.command("redraw")

        print('Answering...1')
        vim.command("redraw")

        printDebug("[chat] messages: {}", messages)
        response = backend.chat(messages)

        def map_chunk(resp):
            printDebug("[chat] response: {}", resp)
            return resp
            # return resp['choices'][0]['delta'].get('content', '')

        # response = (i for i in ["foo", "\nbar", "\nbaz"])
        text_chunks = map(map_chunk, response)
        render_text_chunks(text_chunks, is_selection)

        vim.command("normal! a\n\n>>> user\n\n")
        vim.command("redraw")
        clear_echo_message()
except BaseException as error:
    handle_completion_error(error)
    printDebug("[chat] error: {}", traceback.format_exc())
