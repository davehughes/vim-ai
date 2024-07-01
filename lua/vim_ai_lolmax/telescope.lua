local plugin = require("vim_ai_lolmax")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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

local M = {}

M.choose_model = function()
  plugin.fetch_models(function(models)
    show_model_picker(models)
  end)
end

M.choose_effects = function()
  plugin.fetch_models(function(effects)
    show_effects_picker(effects)
  end)
end

return M
