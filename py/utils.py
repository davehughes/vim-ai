import vim
import datetime
import glob
import os
import socket
import re
from urllib.error import URLError, HTTPError

import sys
import traceback

import urllib.request
import json


class KnownError(Exception):
    pass


class Config:

    @property
    def is_debugging(self):
        return vim.eval("g:vim_ai_debug") == "1"

    @property
    def debug_log_file(self):
        return vim.eval("g:vim_ai_debug_log_file")

    @property
    def pwd(self):
        return vim.eval("getcwd()")

    @property
    def request_timeout(self):
        return 30


config = Config()

# During text manipulation in Vim's visual mode, we utilize "normal! c" command. This command deletes the highlighted text,
# immediately followed by entering insert mode where it generates desirable text.

# Normally, Vim contemplates the position of the first character in selection to decide whether to place the entered text
# before or after the cursor. For instance, if the given line is "abcd", and "abc" is selected for deletion and "1234" is
# written in its place, the result is as expected "1234d" rather than "d1234". However, if "bc" is chosen for deletion, the
# achieved output is "a1234d", whereas "1234ad" is not.

# Despite this, post Vim script's execution of "normal! c", it takes an exit immediately returning to the normal mode. This
# might trigger a potential misalignment issue especially when the most extreme left character is the line’s second character.


# To avoid such pitfalls, the method "need_insert_before_cursor" checks not only the selection status, but also the character
# at the first position of the highlighting. If the selection is off or the first position is not the second character in the line,
# it determines no need for prefixing the cursor.
def need_insert_before_cursor(is_selection):
    if not is_selection == False:
        return False
    pos = vim.eval("getpos(\"'<\")[1:2]")
    if not isinstance(pos, list) or len(pos) != 2:
        raise ValueError(
            "Unexpected getpos value, it should be a list with two elements")
    return pos[
        1] == "1"  # determines if visual selection starts on the first window column


def render_text_chunks(chunks, is_selection):
    generating_text = False
    full_text = ''
    insert_before_cursor = need_insert_before_cursor(is_selection)
    for text in chunks:
        if not text.strip() and not generating_text:
            continue  # trim newlines from the beginning
        generating_text = True
        if insert_before_cursor:
            vim.command("normal! i" + text)
            insert_before_cursor = False
        else:
            vim.command("normal! a" + text)
        vim.command("undojoin")
        vim.command("redraw")
        full_text += text
    if not full_text.strip():
        print_info_message(
            'Empty response received. Tip: You can try modifying the prompt and retry.'
        )


def parse_prompt_and_role(raw_prompt):
    prompt = raw_prompt.strip()
    role = re.split(' |:', prompt)[0]
    if not role.startswith('/'):
        # does not require role
        return (prompt, None)

    prompt = prompt[len(role):].strip()
    role = role[1:]
    return (prompt, role)


def parse_chat_messages(chat_content, pwd=config.pwd):
    lines = chat_content.splitlines()
    messages = []
    for line in lines:
        if line.startswith(">>> system"):
            messages.append({"role": "system", "content": ""})
            continue
        if line.startswith(">>> user"):
            messages.append({"role": "user", "content": ""})
            continue
        if line.startswith(">>> include"):
            messages.append({"role": "include", "content": ""})
            continue
        if line.startswith("<<< assistant"):
            messages.append({"role": "assistant", "content": ""})
            continue
        if not messages:
            continue
        messages[-1]["content"] += "\n" + line

    for message in messages:
        # strip newlines from the content as it causes empty responses
        message["content"] = message["content"].strip()

        if message["role"] == "include":
            message["role"] = "user"
            paths = message["content"].split("\n")
            message["content"] = ""

            for i in range(len(paths)):
                path = os.path.expanduser(paths[i])
                if not os.path.isabs(path):
                    path = os.path.join(pwd, path)

                paths[i] = path

                if '**' in path:
                    paths[i] = None
                    paths.extend(glob.glob(path, recursive=True))

            for path in paths:
                if path is None:
                    continue

                if os.path.isdir(path):
                    continue

                try:
                    with open(path, "r") as file:
                        message[
                            "content"] += f"\n\n==> {path} <==\n" + file.read(
                            )
                except UnicodeDecodeError:
                    message["content"] += "\n\n" + f"==> {path} <=="
                    message["content"] += "\n" + "Binary file, cannot display"

    return messages


def vim_break_undo_sequence():
    # breaks undo sequence (https://vi.stackexchange.com/a/29087)
    vim.command("let &ul=&ul")


def printDebug(text, *args):
    if not config.is_debugging:
        return
    with open(config.debug_log_file, "a") as file:
        file.write(f"[{datetime.datetime.now()}] " + text.format(*args) + "\n")


def print_info_message(msg):
    vim.command("redraw")
    vim.command("normal \\<Esc>")
    vim.command("echohl ErrorMsg")
    vim.command(f"echomsg '{msg}'")
    vim.command("echohl None")


def handle_completion_error(error):
    # nvim throws - pynvim.api.common.NvimError: Keyboard interrupt
    is_nvim_keyboard_interrupt = "Keyboard interrupt" in str(error)
    if isinstance(error, KeyboardInterrupt) or is_nvim_keyboard_interrupt:
        print_info_message("Completion cancelled...")
    elif isinstance(error, URLError) and isinstance(error.reason,
                                                    socket.timeout):
        print_info_message("Request timeout...")
    elif isinstance(error, HTTPError):
        status_code = error.getcode()
        msg = f"OpenAI: HTTPError {status_code}"
        if status_code == 401:
            msg += ' (Hint: verify that your API key is valid)'
        if status_code == 404:
            msg += ' (Hint: verify that you have access to the OpenAI API and to the model)'
        elif status_code == 429:
            msg += ' (Hint: verify that your billing plan is "Pay as you go")'
        print_info_message(msg)
    elif isinstance(error, KnownError):
        print_info_message(str(error))
    else:
        raise error


# clears "Completing..." message from the status line
def clear_echo_message():
    # https://neovim.discourse.group/t/how-to-clear-the-echo-message-in-the-command-line/268/3
    vim.command("call feedkeys(':','nx')")


def initialize_chat_window(prompt=None):
    lines = vim.eval('getline(1, "$")')
    contains_user_prompt = '>>> user' in lines
    if not contains_user_prompt:
        # user role not found, put whole file content as an user prompt
        vim.command("normal! gg")
        populates_options = False
        # TODO: this may be useful for overriding model/role in the current buffer, revisit?
        # populates_options = config_ui['populate_options'] == '1'
        # if populates_options:
        #     vim.command("normal! O[chat-options]")
        #     vim.command("normal! o")
        #     for key, value in config_options.items():
        #         if key == 'initial_prompt':
        #             value = "\\n".join(value)
        #         vim.command("normal! i" + key + "=" + value + "\n")
        vim.command("normal! " + ("o" if populates_options else "O"))
        vim.command("normal! i>>> user\n")

    vim.command("normal! G")
    vim_break_undo_sequence()
    vim.command("redraw")

    file_content = vim.eval('trim(join(getline(1, "$"), "\n"))')
    role_lines = re.findall(r'(^>>> user|^>>> system|^<<< assistant).*',
                            file_content,
                            flags=re.MULTILINE)
    if not role_lines[-1].startswith(">>> user"):
        # last role is not user, most likely completion was cancelled before
        vim.command("normal! o")
        vim.command("normal! i\n>>> user\n\n")

    if prompt:
        vim.command("normal! i" + prompt)
        vim_break_undo_sequence()
        vim.command("redraw")


class LolmaxBackend:

    def __init__(self,
                 root_url="http://localhost:8000",
                 request_timeout=config.request_timeout):
        self.root_url = root_url
        self.request_timeout = request_timeout

    def chat(self, messages, model='perplexity', effects=None):
        effects = effects or []
        url = os.path.join(self.root_url, "chat")
        headers = {
            "Content-Type": "application/json",
        }
        data = dict(
            model=model,
            effects=effects,
            messages=messages,
        )
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req,
                                    timeout=self.request_timeout) as response:
            for line_bytes in response:
                line = line_bytes.decode("utf-8", errors="replace")
                line_obj = json.loads(line)
                yield line_obj["content"]


# chat and completion are very similar now, but tantalizingly difficult to fully DRY up with
# the interleavings of common and bespoke functionality. Leaving as-is for now, since
# It's Fine (tm)
def do_chat():
    prompt, role = parse_prompt_and_role(vim.eval("l:prompt"))
    initialize_chat_window()
    chat_content = vim.eval('trim(join(getline(1, "$"), "\n"))')
    messages = parse_chat_messages(chat_content)

    try:
        if messages[-1]["content"].strip():
            vim.command("normal! Go\n<<< assistant\n\n")
            vim.command("redraw")

            print('Answering...')
            vim.command("redraw")

            printDebug("[chat] Answering with args: {}", sys.argv)
            printDebug("[chat] messages: {}", messages)
            backend = LolmaxBackend()
            text_chunks = backend.chat(messages)
            is_selection = vim.eval("l:is_selection")
            render_text_chunks(text_chunks, is_selection)

            vim.command("normal! a\n\n>>> user\n\n")
            vim.command("redraw")
            clear_echo_message()
    except BaseException as error:
        handle_completion_error(error)
        printDebug("[chat] error: {}", traceback.format_exc())


def do_complete():
    prompt, role = parse_prompt_and_role(vim.eval("l:prompt"))
    messages = [{"role": "user", "content": prompt}]
    try:
        if messages[-1]["content"].strip():
            print('Completing...')
            vim.command("redraw")

            backend = LolmaxBackend()
            text_chunks = backend.chat(messages)
            is_selection = vim.eval("l:is_selection")
            render_text_chunks(text_chunks, is_selection)

            clear_echo_message()
    except BaseException as error:
        handle_completion_error(error)
        printDebug("[complete] error: {}", traceback.format_exc())
