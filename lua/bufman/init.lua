local M = {}

vim.api.nvim_create_augroup('Bufman_Init', {clear = true})
local function set_autocmd()
	vim.api.nvim_create_autocmd({'BufEnter'}, {
		group = 'Bufman_Init',
		pattern = '*',
		callback = function (ev)
			require('bufman.manager').push_stack(ev.buf)
		end
	})
end

M.setup = function(opts)
	require("bufman.config").set(opts)
	local config = require('bufman.config').get()
	if config.sort.method == 'stack' then
		set_autocmd()
	end
end

setmetatable(M, {
	__index = function(t, k)
		local commands = require('bufman.commands')
		setmetatable(t, {__index = commands})
		return commands[k]
	end
})

return M
