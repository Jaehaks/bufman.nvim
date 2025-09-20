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

M.get_bufcount = function ()
	return require('bufman.manager').get_bufcount()
end

M.get_marks = function ()
	return require('bufman.manager').get_marks()
end

return M
