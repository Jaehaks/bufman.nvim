local M = {}

M.toggle_shortcut = function ()
	require('bufman.manager').toggle_shortcut()
end

M.bnext = function ()
	require('bufman.manager').bjump(1)
end

M.bprev = function ()
	require('bufman.manager').bjump(-1)
end

return M
