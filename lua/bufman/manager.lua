local M = {}
local Utils = require('bufman.utils')
local config = require('bufman.config').get()
local ns_id = require('bufman.highlight').ns_id

---@class bm.mark
---@field bufnr number
---@field fullfile string
---@field relfile_pwd string
---@field filename string
---@field fulldir string
---@field reldir_pwd string
---@field minfile string
---@field mindir string
---@field minlevel number
---@field indicator string
---@field shortcut string
---@field icon bm.mark.icon
---@field display_line string string which is displayed in buffer manager to notice this mark

---@class bm.mark.icon
---@field [1] string icon
---@field [2] string icon_hl

---@type bm.mark[]
local marks = {}

---@class bm.state
---@field edit_mode boolean
---@field bm_bufnr number?
---@field bm_winid number?
local state = {
	edit_mode = false,
	bm_bufnr = nil,
	bm_winid = nil,
}

---############################################################################---
---## marks management
---############################################################################---

-- count duplicated filename
---@param duplicate string marks field which concerns duplication
---@param distinguish string marks field which distinguish duplicate field
---@return bm.dupCount[] duplicated information
local function check_duplicated_mark(duplicate, distinguish)
	---@class bm.dupCount
	---@field [string] number

	---@type bm.dupCount[]
	local counts = {}
	for _, mark in ipairs(marks) do
		local cand
		cand = vim.inspect({mark[duplicate], mark[distinguish]})
		counts[cand] = (counts[cand] or 0) + 1
	end
	return counts
end

-- update reldir of marks
---@param counts bm.dupCount[]
local function update_mindir(counts)
	for _, mark in ipairs(marks) do
		local cand
		cand = vim.inspect({mark.filename, mark.mindir})
		if counts[cand] > 1 then
			mark.minlevel = mark.minlevel + 1
			mark.mindir = Utils.sep_unify(Utils.truncate_path(mark.fulldir, mark.minlevel), nil, nil, true)
		end
		mark.minfile = mark.mindir .. mark.filename
	end
end


-- update duplicated reldir of marks
---@param duplicate string marks field which concerns duplication
---@param distinguish string marks field which distinguish duplicate field
---@return boolean
local function update_duplicated(duplicate, distinguish)
	while true do
		local counts = check_duplicated_mark(duplicate, distinguish)
		if Utils.get_length(counts) == #marks then
			break
		end
		if distinguish == 'mindir' then
			update_mindir(counts)
		end
	end
	return true
end

-- Generate shortcuts for buffers
---@return boolean
local function update_shortcuts()
	local charlist = config.shortcut.charlist -- total character list to use shortcut
	local use_first_letter = config.shortcut.use_first_letter
	-- local ignore_chars = '[jkeqhl]' -- charlist to ignore as shortcut
	local ignore_chars = 'jkhl' -- default moving key is ignored
	for _, key in pairs(config.keys) do
		if #key == 1 then
			ignore_chars = ignore_chars .. key
		end
	end
	ignore_chars = '[' .. ignore_chars .. ']'

	-- Remove reserved chars from charlist
	charlist = charlist:gsub(ignore_chars, '')

	-- initialize shortcut
	for _, mark in ipairs(marks) do
		mark.shortcut = ''
	end

	-- First pass: use first letter of filename if available and alphabetic
	if use_first_letter then
		for _, mark in ipairs(marks) do
			local first_char = mark.filename:sub(1, 1):lower()
			if first_char:match('[a-z0-9]') then -- english word / not allowed shortcut
				if string.find(charlist, first_char) then
					mark.shortcut = first_char
					charlist = charlist:gsub(first_char, '')
				end
			end
		end
	end

	-- Second pass: assign remaining characters
	for _, mark in ipairs(marks) do
		if charlist == '' then
			vim.notify('BufferManager : update shortcut error', vim.log.levels.ERROR)
			return false
		end
		if mark.shortcut == '' then
			local char = charlist:sub(1,1) -- Apply charlist in order
			mark.shortcut = char
			charlist = charlist:gsub(char, '')
		end
	end
	return true
end

-- update icon by filename
---@return boolean
local function update_icons()
	-- check nvim-web-devicons
	local devicons_ok, devicons = pcall(require, 'nvim-web-devicons')
	if not devicons_ok then
		return false
	end

	for _, mark in ipairs(marks) do
		mark.icon = {devicons.get_icon(mark.filename)}
	end
	return true
end

-- update indicator
local function update_indicator()
	if state.bm_winid then
		return
	end
	local curbufnr = vim.api.nvim_get_current_buf() -- focused buffer
	local altbufnr = vim.fn.bufnr('#')
	for _, mark in ipairs(marks) do
		local focused = mark.bufnr == curbufnr and '%' or ' '
		local altered = mark.bufnr == altbufnr and '#' or ' '
		local modified = vim.api.nvim_get_option_value("modified", { buf = mark.bufnr }) and '+' or ' '
		mark.indicator = modified .. (focused ~= ' ' and focused or altered)
	end
end

-- reorder marks by method
---@param method string?
---@param reverse boolean
local function update_order(method, reverse)
	if not method then
		return
	elseif method == 'filename' then
		table.sort(marks, function(a, b)
			local a_value = string.lower(a.filename)
			local b_value = string.lower(b.filename)
			return a_value < b_value
		end)
	elseif method == 'bufnr' then
		table.sort(marks, function(a, b)
			return a.bufnr < b.bufnr
		end)
	elseif method == 'lastused' then
		table.sort(marks, function(a, b)
			local a_value = vim.fn.getbufinfo(a.bufnr)[1].lastused
			local b_value = vim.fn.getbufinfo(b.bufnr)[1].lastused
			if a_value == b_value then
				return a.bufnr < b.bufnr
			else
				return a_value > b_value
			end
		end)
	end
	if reverse then
		local reversed_marks = {}
		for i = #marks, 1, -1 do
			table.insert(reversed_marks, marks[i])
		end
		marks = reversed_marks
	end
end

-- get listed buffer list
---@return boolean
local function update_marks()
	-- remove unused mark
	local buf_in_marks = {}
	for i = #marks, 1, -1 do
		if not Utils.is_valid(marks[i].bufnr) then
			table.remove(marks, i)
		else
			table.insert(buf_in_marks, marks[i].bufnr)
		end
	end

	-- add additional buffers to marks
	local buflist = vim.api.nvim_list_bufs()
	local pwd = Utils.sep_unify(vim.fn.fnamemodify(vim.fn.getcwd(0), ':~'), nil, nil, true)
	for _, bufnr in ipairs(buflist) do
		local fullfile = Utils.is_valid(bufnr)
		if fullfile and not vim.tbl_contains(buf_in_marks, bufnr) then
			fullfile = Utils.sep_unify(vim.fn.fnamemodify(fullfile, ':~'))
			local fulldir = Utils.sep_unify(vim.fn.fnamemodify(fullfile, ':~:h'), nil, nil, true)
			local reldir_pwd = Utils.get_relative_path(fulldir, pwd)
			local relfile_pwd = Utils.get_relative_path(fullfile, pwd)
			table.insert(marks, {
				bufnr        = bufnr,
				fullfile     = fullfile,
				relfile_pwd  = relfile_pwd,
				filename     = vim.fn.fnamemodify(fullfile, ':t'),
				fulldir      = fulldir,
				reldir_pwd   = reldir_pwd,
				minfile      = '',
				mindir       = '',
				minlevel     = 0,
				indicator    = '',
				shortcut     = '',
				icon         = {' ', 'Normal'},
				display_line = ''
			})
		end
	end

	local ok = nil
	ok = update_duplicated('filename', 'mindir') -- check duplicated filename, and update mindir by step
	ok = ok and update_shortcuts()   -- set shortcut keymaps to navigate
	ok = ok and update_icons()   -- set shortcut keymaps to navigate
	update_indicator()
	update_order(config.sort.method, config.sort.reverse) -- sort marks by method
	return ok
end

---############################################################################---
---## create buffer manager window
---############################################################################---

-- set window option
---@param contents string[]
local function set_win_opts(contents)
	-- default size of floating window
	local winopts = config.winopts
	local max_width = vim.api.nvim_win_get_width(0) -- max width is width of current file
	local max_height = vim.api.nvim_win_get_height(0)
	local width = winopts.width
	local height = winopts.height or #contents

	-- set window height / width to fit file contents
	-- if <1, it means ratio of window width
	-- if >1, it means count of columns and row
	if width < 1 then
		width = math.floor(vim.o.columns * width)
	end
	if height < 1 then
		height = math.floor(vim.o.lines * height)
	end

	-- set floating window location
	local row = math.floor((max_height - height) / 2)
	local col = math.floor((max_width - width) / 2)

	-- set options of floating windows style
	local opts = {
		title       = 'Buffers',          -- title in window border,
		relative    = 'editor',
		row         = row,                -- start of x(right) index from cursor
		col         = col,                -- start of y(below) index from cursor
		width       = width,              -- width of floating window
		height      = height,             -- height of floating window
		border      = winopts.borderchars -- single round corner
	}
	return opts
end

---@param contents string[] contents from formatter
---@param hlinfos bm.marklist.item[][] highlight information of each components of buffer manager
---@return number buffer id of buffer manager
---@return number window id of buffer manager
local function create_window(contents, hlinfos)
	-- get line number where you focus first
	local focus_line
	if config.focus == 'first' then
		focus_line = 1
	elseif config.focus == 'current' then
		local focus_bufnr = vim.fn.bufnr()
		focus_line = Utils.get_idx_by_key(marks, 'bufnr', focus_bufnr)
	elseif config.focus == 'alternate' then
		local focus_bufnr = vim.fn.bufnr('#')
		focus_bufnr = focus_bufnr < 0 and vim.fn.bufnr() or focus_bufnr
		focus_line = Utils.get_idx_by_key(marks, 'bufnr', focus_bufnr)
	else
		focus_line = 1
	end

	-- open floating window
	local winopts = set_win_opts(contents)

	local bufnr = Utils.get_buf_by_name('bufman')
	if not bufnr then
		bufnr = vim.api.nvim_create_buf(false, false)              -- set buffer temporarily
	end
	local winid = vim.api.nvim_open_win(bufnr, true, winopts)        -- open window and enter
	vim.api.nvim_buf_set_name(bufnr, "bufman")

	-- set contents
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
	Utils.set_highlight(bufnr, ns_id, hlinfos)
	vim.api.nvim_win_set_cursor(winid, {focus_line,0})						 -- set cursor position

	-- set options
	vim.api.nvim_set_option_value("filetype", "bufman", { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
	vim.api.nvim_set_option_value("bufhidden", "delete", { buf = bufnr })
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
	vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
	for scope_type, scope in pairs(config.bufopts) do
		if scope_type == 'winlocal' then
			for key, value in pairs(scope) do
				vim.api.nvim_set_option_value(key, value, { win = winid })
			end
		elseif scope_type == 'buflocal' then
			for key, value in pairs(scope) do
				vim.api.nvim_set_option_value(key, value, { buf = bufnr })
			end
		end
	end

	return bufnr, winid
end

---@class bm.marklist.item
---@field type string format in config.formatter
---@field line number line number in buffer manager to highlight
---@field scol number start column to highlight
---@field ecol number end column to highlight
---@field str string displayed string for each format
---@field len number length of str
---@field hl string highlight group to apply str

-- get highlight information for each mark contents
---@param formatter string[]
---@return bm.marklist.item[][]
local function get_hlinfo(formatter)
	-- get all raw contents using table form
	---@type bm.marklist.item[][]
	local hlinfos = {}
	for i, mark in ipairs(marks) do
		---@type bm.marklist.item[]
		local hlinfo = {}
		for _, format in ipairs(formatter) do
			---@type bm.marklist.item
			local item = {}
			if format == 'icon' then
				item.str = mark.icon[1]
				item.hl = mark.icon[2]
			elseif format == 'shortcut' then
				item.str = mark.shortcut
				item.hl = 'BufmanShortcut'
			else
				item.str = tostring(mark[format])
				item.hl = ''
			end
			item.len = vim.api.nvim_strwidth(item.str)
			item.type = format
			item.line = i - 1
			table.insert(hlinfo, item)
		end
		table.insert(hlinfos, hlinfo)
	end

	return hlinfos
end

---@param formatter string[]
---@return string[] contents table that will be displayed in buffer manager
---@return bm.marklist.item[][] raw data of contents to highlight
local function get_marklist(formatter)
	local formatlist = vim.deepcopy(formatter)

	-- remove shortcut / icon in edit mode
	if state.edit_mode then
		local remove_format = {'shortcut', 'icon', 'bufnr', 'indicator'}
		for _, format in ipairs(remove_format) do
			local idx = Utils.get_idx_by_value(formatlist, format)
			if idx then
				table.remove(formatlist, idx)
			end
		end
	end

	---@type bm.marklist.item[][]
	local hlinfos = get_hlinfo(formatlist)

	-- calculate max length of items
	local tbl_maxlen = Utils.get_contents_maxlen(hlinfos)

	-- adjust each column with white space
	local contents = {}
	for k, hlinfo in ipairs(hlinfos) do
		local result = {}
		local len_result = 0
		for i, item in ipairs(hlinfo) do
			local diff = tbl_maxlen[i] - item.len
			local item_adj = item.str .. string.rep(' ', diff)
			table.insert(result, item_adj)
			item.scol = len_result
			item.ecol = item.scol + #item.str
			len_result = len_result + #item_adj + 1 -- consider ' '
			if item.len == 0 then
				item.scol = hlinfo[i-1].ecol
				item.ecol = hlinfo[i-1].ecol
			end
		end
		local display_line = string.gsub(table.concat(result, ' '), '%s+$', '') -- remove white space at end
		table.insert(contents, display_line)
		marks[k].display_line = display_line -- update mark.display_line
	end

	return contents, hlinfos
end


---############################################################################---
---## set keymaps
---############################################################################---

-- update marks from buffer manager contents
---@param bufnr number buffer id of buffer manager
local function update_contents(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- create line hash to check line buffer is
	local line_hash = {}
	for _, line in ipairs(lines) do
		if line:match('%S') then -- if not empty
			line_hash[line] = true
		end
	end

	-- remove buffer which is deleted in buffer manager and mark is synchronized
	for i = #marks, 1, -1 do
		local mark = marks[i]
		if not line_hash[mark.display_line] then
			if vim.api.nvim_buf_is_valid(mark.bufnr) then
				Utils.close_buf(mark.bufnr)
			end
			table.remove(marks, i)
		end
	end

	-- Refresh the marks
	local ok = update_marks()
	if not ok then return end
	local contents, hlinfos = get_marklist(config.formatter)
	local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = bufnr })
	vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
	Utils.set_highlight(bufnr, ns_id, hlinfos)
	vim.api.nvim_set_option_value('modifiable', modifiable, { buf = bufnr })
end

-- toggle edit status
---@param bufnr number
---@param winid number
local function toggle_edit(bufnr, winid)
	state.edit_mode = not state.edit_mode
	update_contents(bufnr)
	vim.api.nvim_set_option_value('modifiable', state.edit_mode, { buf = bufnr })
	vim.api.nvim_set_option_value('cursorline', not state.edit_mode, { win = winid })
end

-- remove keymap in normal mode
---@param key string
local function block_key(key)
	if state.edit_mode then
		vim.cmd('normal! ' .. key)
	end
end

-- close buffer manager
---@param winid number
---@param force_save boolean
local function close_win(winid, force_save)
	force_save = force_save or false
	vim.api.nvim_win_close(winid, force_save)
end

-- close buffer manager considering edit_mode
---@param bufnr number
---@param winid number
local function update_and_close_win(bufnr, winid)
	if state.edit_mode then
		update_contents(bufnr)
		-- state.edit_mode = false
	end
	close_win(winid, true)
end

-- close buffer manager and open buffer
---@param bufnr number if 0, open mark at current cursor,
---@param winid number buffer manager's winid
---@param fallback_key string key in edit mode
---@param cmd string? Other command to open buffer except of opening in last window
local function go_to_buffer(bufnr, winid, fallback_key, cmd)
	if state.edit_mode then
		vim.cmd('normal! ' .. fallback_key)
		return
	end
	if bufnr == 0 then
		local idx = vim.fn.line('.')
		bufnr = marks[idx].bufnr
	end
	close_win(winid, true)
	if cmd then vim.cmd(cmd) end
	vim.api.nvim_set_current_buf(bufnr)
end

-- reorder items by level, +1 means the mark goes up, -1 means down
---@param level number how much you change order from current state
---@return number start_idx
---@return number end_idx
local function reorder_marks(level)
	local start_idx = vim.fn.getpos('v')[2]
	local end_idx   = vim.fn.getpos('.')[2]
	local diff_idx = end_idx - start_idx
	local dest_start_idx = start_idx - level
	local dest_end_idx = end_idx - level
	if dest_start_idx < 1 then
		dest_start_idx = 1
		dest_end_idx = dest_start_idx + diff_idx
	elseif dest_end_idx > #marks then
		dest_end_idx = #marks
		dest_start_idx = dest_end_idx - diff_idx
	end

	-- insert item before dest_start_idx
	local new_marks = {}
	local new_idx = 1
	local choices_inserted = false
	for i = 1, #marks do
		if new_idx == dest_start_idx then
			for k = start_idx, end_idx do
				new_marks[new_idx] = marks[k]
				new_idx = new_idx + 1
			end
			choices_inserted = true
		end

		if i < start_idx or i > end_idx then
			new_marks[new_idx] = marks[i]
			new_idx = new_idx + 1
		end
	end

	-- insert rest of items
	if not choices_inserted then
		for i = start_idx, end_idx do
			new_marks[new_idx] = marks[i]
			new_idx = new_idx + 1
		end
	end
	marks = new_marks
	return start_idx, end_idx
end

-- reorder contents
---@param level number how far to move items, +1 to up, -1 to down
local function reorder_contents(level)
	if config.sort.method then
		return
	end

	-- 'move' command more complicate to set mark, use set_liens()
	local start_line, end_line = reorder_marks(level)
	local contents, hlinfos = get_marklist(config.formatter)
	vim.api.nvim_set_option_value('modifiable', true, { buf = state.bm_bufnr })
	vim.api.nvim_buf_set_lines(state.bm_bufnr, 0, -1, false, contents)
	Utils.set_highlight(state.bm_bufnr, ns_id, hlinfos)
	vim.api.nvim_set_option_value('modifiable', false, { buf = state.bm_bufnr })

	-- change cursor / visual region
	local line_count = vim.api.nvim_buf_line_count(state.bm_bufnr)
	local mode = vim.fn.mode()
	local diff = end_line - start_line
	local start_cursor = (start_line - level) < 1 and 1 or start_line - level
	local end_cursor = (end_line - level) > line_count and line_count or end_line - level
	start_cursor = end_cursor >= line_count and end_cursor - diff or start_cursor
	end_cursor = start_cursor <= 1 and start_cursor + diff or end_cursor
	if vim.tbl_contains({'v', 'V'}, mode) then
		vim.api.nvim_buf_set_mark(state.bm_bufnr, '<', start_cursor, 0, {})
		vim.api.nvim_buf_set_mark(state.bm_bufnr, '>', end_cursor, 999, {})
		vim.cmd('normal! gv')
	else
		vim.api.nvim_win_set_cursor(state.bm_winid, {start_cursor,0})
	end
end

-- set default keymaps
---@param bufnr number if 0, open mark at current cursor,
---@param winid number buffer manager's winid
local function set_keymaps(bufnr, winid)
	local opts = { buffer = bufnr, silent = true, nowait = true }

	-- toggle key
	vim.keymap.set('n', config.keys.toggle_edit, function() toggle_edit(bufnr, winid) end, opts)

	-- sort key
	vim.keymap.set({'n', 'v'}, config.keys.reorder_upper, function () reorder_contents(1) end, opts)
	vim.keymap.set({'n', 'v'}, config.keys.reorder_lower, function () reorder_contents(-1) end, opts)

	-- Exit edit mode or close window
	vim.keymap.set('n', config.keys.update_and_close, function() update_and_close_win(bufnr, winid) end, opts)
	vim.keymap.set('n', config.keys.close, function() close_win(winid, true) end, opts)

	-- go to buffer using shortcut, <CR>
	for _, mark in ipairs(marks) do
		vim.keymap.set('n', mark.shortcut, function() go_to_buffer(mark.bufnr, winid, mark.shortcut) end, opts)
	end
	vim.keymap.set('n', '<CR>', function() go_to_buffer(0, winid, '<CR>') end, opts)

	-- set extra commands
	for key, cmd in pairs(config.extra_keys) do
		vim.keymap.set('n', key, function() go_to_buffer(0, winid, key, cmd) end, opts)
	end
end

---############################################################################---
---## set autocmds
---############################################################################---

local function set_autocmds(bufnr, winid)
	-- reset bm_winid at closed
	vim.api.nvim_create_augroup('Bufman_Manager', {clear = true})
	vim.api.nvim_create_autocmd('WinClosed', {
		buffer = bufnr,
		group = 'Bufman_Manager',
		callback = function ()
			-- if bufman_bufnr then
			-- 	vim.api.nvim_buf_delete(bufman_bufnr, { force = false })
			-- end
			state.bm_winid = nil
			state.bm_bufnr = nil
			state.edit_mode = false
		end
	})
end

---############################################################################---
---## command
---############################################################################---

-- open/close shortcut window
M.toggle_shortcut = function ()
	if state.bm_winid then -- if it is already opened, return
		update_and_close_win(state.bm_bufnr, state.bm_winid)
		return
	end
	local ok = update_marks()
	if not ok then return end
	local contents, hlinfos = get_marklist(config.formatter)
	state.bm_bufnr, state.bm_winid = create_window(contents, hlinfos)
	set_keymaps(state.bm_bufnr, state.bm_winid)
	set_autocmds(state.bm_bufnr, state.bm_winid)
end

M.bjump = function (level)
	update_marks()
	local bufnr = vim.api.nvim_get_current_buf()
	local idx = Utils.get_idx_by_key(marks, 'bufnr', bufnr)
	idx = idx + level
	idx = idx > #marks and #marks or (idx < 1 and 1 or idx)
	bufnr = marks[idx].bufnr
	vim.api.nvim_set_current_buf(bufnr)
end



return M
