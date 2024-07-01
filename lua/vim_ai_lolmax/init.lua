local curl = require("plenary.curl")
local root_url = vim.g.lolmax_root_url

local M = {}

local function fetch_data(url, callback)
  curl.get(url, {
    callback = function(response)
      callback(response.body)
    end
  })
end

M.invoke = function(prompt, model, effects, callback)
  curl.post(root_url .. "/invoke", {
    headers = {
      content_type = "application/json",
    },
    body = vim.fn.json_encode({
      model = model,
      effects = effects,
      messages = {
        { role = "user", content = prompt }
      }
    }),
    callback = function(response)
      vim.schedule(function()
        callback(vim.fn.json_decode(response.body))
      end)
    end
  })
end

M.fetch_info = function(callback)
  fetch_data(root_url .. "/info", function(result_str)
    vim.schedule(function()
      callback(vim.fn.json_decode(result_str))
    end)
  end)
end


M.fetch_models = function(callback)
  M.fetch_info(function(info_obj)
    callback(info_obj["models"])
  end)
end

M.fetch_effects = function(callback)
  M.fetch_info(function(info_obj)
    callback(info_obj["effects"])
  end)
end

return M
