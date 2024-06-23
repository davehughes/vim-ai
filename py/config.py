import vim

# _plugin_root = vim.eval("s:plugin_root")
# vim.command(f"py3file {_plugin_root}/py/utils.py")

# is_debugging = vim.eval("g:vim_ai_debug") == "1"
# debug_log_file = vim.eval("g:vim_ai_debug_log_file")

# TODO: options for current role (optional) and model (required, unless backend supports a default?)
# + endpoint_url -> to lolmax API root
# + request_timeout ->
# + enable_auth -> punt, assume local unauthenticated backend for now

# prompt, role_options = parse_prompt_and_role(vim.eval("l:prompt"))
# config = normalize_config(vim.eval("l:config"))
# config_options = {
#     **config['options'],
#     **role_options['options_default'],
#     **role_options['options_chat'],
# }
# config_ui = config['ui']
#
# chat_options = parse_chat_header_options()
# options = {**config_options, **chat_options}
# # openai_options = make_openai_options(options)
# http_options = make_http_options(options)

# TODO: merge these with prefixes e.g. 'open_ai_blah', 'http_whatever', ...


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
