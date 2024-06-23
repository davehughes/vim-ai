import os
import random

import json

import urllib
import vim


# import utils
plugin_root = vim.eval("s:plugin_root")
vim.command(f"py3file {plugin_root}/py/config.py")


class LoremIpsumBackend:

    def chat(self, messages, model='default', role='default'):
        snippets = [
            '''foo
            bar 
            baz''',
            '''lorem ipsum
            etc.
            and so 
            and on 
            ''',
        ]
        lines = random.sample(snippets, 1)[0].splitlines()
        for line in lines:
            yield line


class LolmaxBackend:

    def __init__(self,
                 root_url="http://localhost:8118",
                 request_timeout=config.request_timeout):
        self.root_url = root_url

    def chat(self, messages, model='default', role='default'):
        url = os.path.join(self.root_url, "chat")
        headers = {
            "Content-Type": "application/json",
        }
        data = dict(
            model=model,
            role=role,
            messages=messages,
        )
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        # TODO: make this configurable
        request_timeout = 30
        with urllib.request.urlopen(req, timeout=request_timeout) as response:
            for line_bytes in response:
                line = line_bytes.decode("utf-8", errors="replace")


# OPENAI_RESP_DATA_PREFIX = 'data: '
# OPENAI_RESP_DONE = '[DONE]'
#
#
# class OpenAIBackend:
#
#     def __init__(self, api_key, org_id, options):
#         self.api_key = api_key
#         self.org_id = org_id
#         self.options = options
#
#     def chat(self, messages, request_options):
#         request = {
#             'stream': True,
#             'messages': messages,
#             **request_options,
#         }
#         printDebug("[chat] request: {}", request)
#         url = options['endpoint_url']
#         response = self.request(url, request, http_options)
#
#         def map_chunk(resp):
#             printDebug("[chat] response: {}", resp)
#             return resp['choices'][0]['delta'].get('content', '')
#
#         return map(map_chunk, response)
#
#     def request(self, url, data, options):
#         enable_auth = options['enable_auth']
#         headers = {
#             "Content-Type": "application/json",
#         }
#         if enable_auth:
#             headers['Authorization'] = f"Bearer {self.api_key}"
#
#             if self.org_id is not None:
#                 headers["OpenAI-Organization"] = self.org_id
#
#         request_timeout = options['request_timeout']
#         req = urllib.request.Request(
#             url,
#             data=json.dumps(data).encode("utf-8"),
#             headers=headers,
#             method="POST",
#         )
#         with urllib.request.urlopen(req, timeout=request_timeout) as response:
#             for line_bytes in response:
#                 line = line_bytes.decode("utf-8", errors="replace")
#                 if line.startswith(OPENAI_RESP_DATA_PREFIX):
#                     line_data = line[len(OPENAI_RESP_DATA_PREFIX):-1]
#                     if line_data.strip() == OPENAI_RESP_DONE:
#                         pass
#                     else:
#                         openai_obj = json.loads(line_data)
#                         yield openai_obj
