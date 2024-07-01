local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugin requires nvim-telescope/telescope.nvim')
end

local telescope_extension = require("vim_ai_lolmax.telescope")

return telescope.register_extension {
  exports = {
    vim_ai_lolmax = telescope_extension.choose_model,
    choose_model = telescope_extension.choose_model,
    choose_effects = telescope_extension.choose_effects
  },
}
