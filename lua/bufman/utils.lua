local M = {}

-- check OS
local WinOS = vim.fn.has('win32') == 1
local sep = WinOS and '\\' or '/'

---@return boolean
M.is_WinOS = function()
	return WinOS
end

-- change separator on directory depends on OS
---@param path string relative path
---@param sep_to string? path separator after change
---@param sep_from string? path separator before change
---@param endslash boolean? add slash end of path or not
M.sep_unify = function(path, sep_to, sep_from, endslash)
	sep_to = sep_to or (WinOS and '\\' or '/')
	sep_from = sep_from or ((sep_to == '/') and '\\' or '/')
	local endchar = endslash and sep_to or ''
	return path:gsub('[/\\]+$', ''):gsub(sep_from, sep_to) .. endchar
end

-- get number of items of table
---@return number
M.get_length = function(T)
	local count = 0
	for _, _ in pairs(T) do
		count = count + 1
	end
	return count
end

-- check buffer id
---@param bufnr number buffer id
---@return string? filename of bufnr
M.is_valid = function(bufnr)
	local buflisted = vim.fn.buflisted(bufnr) == 1
	if buflisted then
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		if filepath ~= '' then
			return filepath
		end
	end
	return nil
end

-- return listed buffer list
---@return number[]
local function get_valid_buflist()
	local valid_buflist = {}
	local buflist = vim.api.nvim_list_bufs()
	for _, bufid in ipairs(buflist) do
		if M.is_valid(bufid) then
			table.insert(valid_buflist, bufid)
		end
	end
	return valid_buflist
end

-- return any alternative buffer id which don't have bufnr from listed buffer list
-- if therea are no alternative buffers, create new empty buffer
---@param bufnr number target buffer which is not included alternative group
---@return number alternative buffer
local function get_alterbuf(bufnr)
	local buflist = get_valid_buflist()
	for _, bufid in ipairs(buflist) do
		if bufid ~= bufnr then
			return bufid
		end
	end
	local newbufnr = vim.api.nvim_create_buf(false, true)
	return newbufnr
end

-- if a buffer which you want to remove is in last window and you are focusing floating window,
-- nvim_buf_delete() cannot delete buffer. because it is in last window.
-- It needs to change contents in last window to implement safe close buffer
---@param bufnr number target buffer to close
M.close_buf = function(bufnr)
	local alterbufnr = get_alterbuf(bufnr)
	local wins = vim.api.nvim_list_wins()
	for _, winid in ipairs(wins) do
		if vim.api.nvim_win_get_buf(winid) == bufnr  then
			vim.api.nvim_win_set_buf(winid, alterbufnr)
		end
	end
	vim.api.nvim_buf_delete(bufnr, { force = false })
end

---@param path string absolute path to truncate (ends without slash)
---@param level number truncation level
---@return string path from most-sub directory depends on level.
M.truncate_path = function(path, level)
	-- split directory
	local parts = vim.split(path, '[\\/]')

	level = math.max(1, math.min(#parts, level))
	local result = ''
	for i = #parts, #parts-level+1, -1 do
		result = parts[i] .. sep .. result
	end
	if level < #parts then -- add ':' for relative path
		result = ':' .. result
	end
	return result
end

-- get relative path based on basedir first. if not, original file
---@param filepath string absolute path to make relative path
---@param basedir string absolute path which is the base, (it must ends with slash)
---@return string relative path of filepath
M.get_relative_path = function(filepath, basedir)
	local path
	if filepath:sub(1, #basedir) == basedir then
		path = ':' .. filepath:sub(#basedir + 1)
	else
		path = filepath
	end
	return M.sep_unify(path, sep, nil, true)
end

-- get index of marks which is matched bufnr
---@param marks bm.mark[]
---@param bufnr number buffer id
M.get_idx_from_buf = function(marks, bufnr)
	for k, mark in ipairs(marks) do
		if mark.bufnr == bufnr then
			return k
		end
	end
	return nil
end

return M
