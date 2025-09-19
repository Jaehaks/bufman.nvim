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

-- return bufnr which is matched with buffer name
-- vim.fn.bufnr(name) cannot find the buffer properly when listed buffer is only one.
---@param bufname string buffer name
---@return number?
M.get_buf_by_name = function(bufname)
	local buflist = vim.api.nvim_list_bufs()
	for _, bufid in ipairs(buflist) do
		local name = vim.api.nvim_buf_get_name(bufid)
		name = vim.fn.fnamemodify(name, ':t')
		if name == bufname then
			return bufid
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
	return M.sep_unify(path, sep, nil, vim.fn.filereadable(vim.fn.expand(filepath)) == 0)
end

-- get index of marks which is matched value which is matched key
---@param T table
---@param item string
---@param value any
---@return number?
M.get_idx_by_key = function(T, item, value)
	for k, t in ipairs(T) do
		if t[item] == value then
			return k
		end
	end
	return nil
end

-- get index of marks which is matched value only
---@param T table
---@param value any
---@return number?
M.get_idx_by_value = function(T, value)
	for k, t in ipairs(T) do
		if t == value then
			return k
		end
	end
	return nil
end


-- get max length of each items in contents
---@param T bm.marklist.item[][]
---@return number[]
M.get_contents_maxlen = function (T)
	local tbl_maxlen = {}
	local maxlen = 0
	local len_item = #T[1]
	for i = 1, len_item do
		maxlen = 0
		for _, t in ipairs(T) do
			if t[i].len > maxlen then
				maxlen = t[i].len
			end
		end
		tbl_maxlen[i] = maxlen
	end
	return tbl_maxlen
end

-- set highlight to buffer
---@param bufnr number
---@param ns_id number namespace id
---@param raws bm.marklist.item[][]
M.set_highlight = function(bufnr, ns_id, raws)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	for _, raw in ipairs(raws) do
		for _, item in ipairs(raw) do
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, item.line, item.scol, {end_col = item.ecol, hl_group = item.hl})
		end
	end
end


return M
