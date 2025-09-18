local M = {}

M.ns_id = vim.api.nvim_create_namespace('Bufman')

-- vim.api.nvim_set_hl(M.ns_id, 'BufmanShortcut', {fg = '#33FF33', bold = true})
vim.api.nvim_set_hl(0, 'BufmanShortcut', {fg = '#33FF33', bold = true})


return M
