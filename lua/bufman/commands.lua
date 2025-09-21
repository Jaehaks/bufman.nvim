local M = {}

M.toggle_manager = function ()
	require('bufman.manager').toggle_manager()
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

M.get_stacks = function ()
	return require('bufman.manager').get_stacks()
end

return M
