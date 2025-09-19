local M = {}

-- default configuration
---@class bm.config
---@field shortcut bm.config.shortcut
---@field formatter string[]
---@field extra_keys table<string, string>
---@field winopts table
---@field bufopts table additional option for buffer
---@field sort bm.config.sort
---@field focus string

---@alias bm.config.formatter fun(mark: bm.mark):table

---@class bm.config.shortcut
---@field charlist string
---@field use_first_letter boolean

---@class bm.config.sort
---@field method string?
---@field reverse boolean

---@type bm.config
local default_config = {
	-- prefix shortcut to open buffer
	-- [jkeq] will be ignored although these characters are in charlist
	shortcut = {
		charlist = 'qwertyuiopasdfghlzxcvbnm', -- 20 buffers are supported
		use_first_letter = true, -- if true, set shortcut following first letter of file name
								 -- If first letter is duplicated, it will be set by charlist
	},
	formatter = {'shortcut', 'icon', 'filename', 'relfile_pwd', 'minpath'},
	-- extra keys to open in mormal mode
	-- insert 'key = command' what you want
	-- it is same with vim.cmd(command <selected item>) if you enter 'key' in normal mode
	extra_keys = {
		['<C-v>'] = 'vsplit',
		['<C-h>'] = 'split',
	},
	-- window options
	-- these items are supported only
	winopts = {
		-- if 0~1 of width/height, it means that ratio of floating window to the neovim instance size
		-- if > 1, it means lines/columns of floating window
		-- if nil, it will fit to the contents of floating window
		width = 0.9,
		height = nil,
		borderchars = 'rounded',
	},
	-- if you want to change additional option of buffer manager, you can this
	-- It will be used by vim.api.nvim_set_option_value(key, value, { win = winid } or { buf = bufnr })
	bufopts = {
		winlocal = {
			number = false,
			relativenumber = false,
			signcolumn = 'no',
		},
		buflocal = {
		},
	},
	-- sort buffer by bufnr|lastused|filename for navigating
	-- if you don't want to sort, use nil
	sort = {
		method = nil,
		reverse = false,
	},
	-- where you cursor focus at buffer manager startup
	-- first : first line
	-- current : current buffer
	-- alternate : alternate buffer
	focus = 'alternate', -- where first|current|alternate
}

local config = vim.deepcopy(default_config)

-- get configuration
---@return bm.config
M.get = function ()
	return config
end

-- set configuration
M.set = function (opts)
	config = vim.tbl_deep_extend('force', default_config, opts or {})
end


return M
