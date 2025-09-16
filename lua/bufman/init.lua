local M = {}

M.setup = function(opts)
	require("bufman.config").set(opts)
end

setmetatable(M, {
	__index = function(t, k)
		local commands = require('bufman.commands')
		setmetatable(t, {__index = commands})
		return commands[k]
	end
})

return M
