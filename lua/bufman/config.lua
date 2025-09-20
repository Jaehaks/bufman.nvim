local M = {}

-- default configuration
---@class bm.config
---@field shortcut bm.config.shortcut
---@field formatter string[]
---@field keys bm.config.keys
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

---@class bm.config.keys
---@field toggle_edit string
---@field reorder_upper string
---@field reorder_lower string
---@field update_and_close string
---@field close string

---@type bm.config
local default_config = {
	-- prefix shortcut to open buffer
	-- [jkeq] will be ignored although these characters are in charlist
	shortcut = {
		charlist = 'qwertyuiopasdfghlzxcvbnmQWERTYUIOPASDFGHLZXCVBNM', -- 44 buffers are supported
		use_first_letter = true, -- if true, set shortcut following first letter of file name
								 -- If first letter is duplicated, it will be set by charlist
	},
	-- Format which items are shown in buffer manager.
	-- All absolute paths are displayed with relative of '~'.
	-- All relative paths starts with ':' if they are displayed under ~
	-- These fields will be separated with white space and left aligned.
	-- In edit mode with 'e', {bufnr, icon, shortcut, indicator} will be hidden.
	-- bufnr : buffer id
	-- fullfile : absolute path of file
	-- relfile_pwd : relative file path of current pwd of focused buffer before buffer manager opens
	-- filename : filename and extension only
	-- fulldir : absolute path of parent directory of each file
	-- reldir_pwd : relative parent directory path of current pwd of focused buffer
	-- minfile : show filename as default, prepends parent path until these files can be distinguished
	-- 			 when they have same filename. such as ':bufman/init.lua'
	-- mindir : show empty as default, show parent path until these files can be distinguished
	-- 			when they have same filename. ':bufman/'
	-- indicator : 2 characters which supports showing buffer states. +# or +%
	-- 			   + means modified / # means alternate buffer / % means current focused buffer
	-- shortcut : shortcut to go to buffer (required)
	-- icon : icon by nvim-web-devicons
	formatter = {'shortcut', 'icon', 'indicator', 'filename', 'mindir', 'relfile_pwd'},
	-- default keys in buffer manager operation
	keys = {
		toggle_edit = 'e',      -- toggle edit mode
		reorder_upper = 'K',    -- reorder selected buffer to upper direction in buffer manager
		reorder_lower = 'J',    -- reorder selected buffer to lower direction in buffer manager
		update_and_close = 'q', -- apply current buffer manager state and close
		close = '<Esc>',        -- close without applying buffer manager state
	},
	-- extra keys to open in mormal mode
	-- insert 'key = command' what you want
	-- it is same with vim.cmd(command <selected item>) if you enter 'key' in normal mode
	extra_keys = {
		['<C-v>'] = 'vsplit', -- open selected buffer with vertical split
		['<C-h>'] = 'split',  -- open selected buffer with horizontal split
		['<C-f>'] = 'only',   -- open selected buffer to fullscreen
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
