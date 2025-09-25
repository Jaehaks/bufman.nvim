local M = {}

M.ns_id = vim.api.nvim_create_namespace('Bufman')

-- define highlight using namespace 0
-- vim.api.nvim_set_hl(M.ns_id, 'BufmanShortcut', {fg = '#33FF33', bold = true})
vim.api.nvim_set_hl(0, 'BufmanShortcut', {fg = '#33FF33', bold = true})
vim.api.nvim_set_hl(0, 'BufmanWinTitleDefault', {fg = '#D19A66'})
vim.api.nvim_set_hl(0, 'BufmanWinTitleEdit', {})
vim.api.nvim_set_hl(0, 'BufmanWinTitleSort', {fg = '#9CDCFE'})
vim.api.nvim_set_hl(0, 'BufmanWinTitleSortReverse', {fg = '#FF8A8A'})


return M
