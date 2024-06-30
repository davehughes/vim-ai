vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("telescope").load_extension("vim_ai_lolmax")
  end,
})
