local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugin requires nvim-telescope/telescope.nvim')
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local curl = require("plenary.curl")

local root_url = vim.g.lolmax_root_url

local function make_display_string(item, current_selection)
  local marker = ""
  if item["name"] == current_selection then
    marker = " (currently selected)"
  end
  return item["name"] .. marker
end

-- pretty-print json
local function encode_with_indent(data, level)
  level = level or 0
  local indent = string.rep("  ", level)
  if type(data) == "table" then
    local items = {}
    local is_array = #data > 0
    for k, v in pairs(data) do
      if is_array then
        table.insert(items, encode_with_indent(v, level + 1))
      else
        table.insert(items, indent .. "  " .. vim.json.encode(k) .. ": " .. encode_with_indent(v, level + 1))
      end
    end
    if is_array then
      return "[\n" .. indent .. "  " .. table.concat(items, ",\n" .. indent .. "  ") .. "\n" .. indent .. "]"
    else
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "}"
    end
  else
    return vim.json.encode(data)
  end
end

local function fetch_data(url, callback)
  curl.get(url, {
    callback = function(response)
      callback(response.body)
    end
  })
end

local function show_model_picker(items)
  pickers.new({}, {
    prompt_title = "Choose Chat Model Profile",
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          display = make_display_string(item, vim.g.vim_ai_model),
          ordinal = make_display_string(item),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Profile Configuration",
      define_preview = function(self, entry, status)
        local content = encode_with_indent(entry.value)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))
        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "json")
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.g.vim_ai_model = selection.value.name
      end)
      return true
    end,
  }):find()
end

local function show_effects_picker(items)
  pickers.new({}, {
    prompt_title = "Choose Chat Model Effects",
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          display = make_display_string(item, nil),
          ordinal = make_display_string(item),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Profile Configuration",
      define_preview = function(self, entry, status)
        local content = encode_with_indent(entry.value)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))
        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "json")
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        print("TODO: toggle effect: " .. selection.value.name)
        -- vim.g.vim_ai_model = selection.value.name
      end)
      return true
    end,
  }):find()
end

local function choose_model()
  fetch_data(root_url .. "/info", function(result_str)
    local result = vim.json.decode(result_str)
    local items = result["models"]
    vim.schedule(function()
      show_model_picker(items)
    end)
  end)
end

local function choose_effects()
  fetch_data(root_url .. "/info", function(result_str)
    local result = vim.json.decode(result_str)
    local items = result["effects"]
    vim.schedule(function()
      show_effects_picker(items)
    end)
  end)
end

return telescope.register_extension {
  exports = {
    vim_ai_lolmax = choose_model,
    choose_model = choose_model,
    choose_effects = choose_effects
  },
}
