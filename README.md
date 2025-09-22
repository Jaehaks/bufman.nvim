# bufman.nvim
Buffer manager of nvim that meets what I want.

# Why?
There are so many good buffer manager. This plugins was made to bringing their strengths.

# Features

1) Use shortcut using characters, you can select two mode (use first char or not)
2) Support toggling edit mode.
	- you can delete buffers what you want.
3) Reorder/sort selected buffer. (support visual mode)
	- manually or by some criteria
4) Easy customization to display buffer using table.
5) Support alternative of `:bnext` / `:bprev` depends on reorder state.
6) Fast open buffer when it is selected.

# requirements
- [Neovim v0.11+](https://github.com/neovim/neovim)

# Installation

If you use `lazy.nvim`.


```lua
return {
  'Jaehaks/bufman.nvim',
  keys = {
    { '<leader>fb', function () require('bufman').toggle_manager() end , {noremap = true, desc = 'open buffer window'} },
    { '<M-m>', function() require('bufman').bnext() end, {noremap = true, desc = 'go to next buffer'} },
    { '<M-n>', function() require('bufman').bprev() end, {noremap = true, desc = 'go to previous buffer'} },
  },
  opts = {

  }
}
```


# Configuration

<details>
	<summary> Default configuration </summary>

- Default configuration of `bufman` is like this.

```lua
require('bufman').setup({
  -- Prefix shortcut to open buffer
  -- [jkhl] and [keys in configuration] will be ignored although these characters are in charlist
  shortcut = {
    charlist = 'qwertyuiopasdfghlzxcvbnmQWERTYUIOPASDFGHLZXCVBNM', -- 44 buffers are supported
    use_first_letter = true, -- if true, set shortcut following first letter of file name
    -- If first letters of files are duplicated, from the seconds one onwards, it will be set by order of charlist.
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

  -- Default keys in buffer manager operation
  keys = {
    toggle_edit = 'e',      -- toggle edit mode
    reorder_upper = 'K',    -- reorder selected buffer to upper direction in buffer manager
    reorder_lower = 'J',    -- reorder selected buffer to lower direction in buffer manager
    update_and_close = 'q', -- apply current buffer manager state and close
    close = '<Esc>',        -- close without applying buffer manager state
  },

  -- Extra keys to open in mormal mode of buffer manager.
  -- Insert 'key = command' what you want.
  -- it is same with vim.cmd(command <selected item>) if you enter 'key' in normal mode
  extra_keys = {
    ['<C-v>'] = 'vsplit', -- open selected buffer with vertical split
    ['<C-h>'] = 'split',  -- open selected buffer with horizontal split
    ['<C-f>'] = 'only',   -- open selected buffer to fullscreen
  },

  -- Window options
  -- Three items are supported only
  winopts = {
    -- if 0~1 of width/height, it means that ratio of floating window to the neovim instance size
    -- if > 1, it means lines/columns of floating window
    -- if nil, it will fit to the contents of floating window
    width = 0.9,
    height = nil,
    borderchars = 'rounded',
  },

  -- If you want to change additional option of buffer manager, you can this
  -- It will be used by vim.api.nvim_set_option_value(key, value, { win = winid } or { buf = bufnr })
  -- If you set vim.o.number / relativenumber already in your own option, this option will apply to the
  -- buffer manager automatically, and the option value in `winlocal` is useless.
  bufopts = {
    winlocal = {
      number = false,
      relativenumber = false,
      signcolumn = 'no',
    },
    buflocal = {
    },
  },

  -- sort buffer by {bufnr|lastused|filename|stack} method for navigating
  -- if you don't want to sort, use nil (manual mode)
  -- you can reorder buffer using upper/lower key in manual mode only.
  -- bufnr : buffer number
  -- lastused : last visited date. using getinfo()
  -- 		    It is useful if you go to alternate buffer only when using bnext()/bprev().
  -- filename : file name only.
  -- stack : visited history.
  -- 		 It consider distance index from current buffer. if you have 5 buffers,
  -- 		 these indexes are {1,2,3,4,5}, 1<->2 distance is 1, 1<->4 distance is 3.
  -- 		 If you jump any buffer which has more than 2 distances from current buffer,
  -- 		 the buffer is add to top of stack and remove original position If the buffer is in stack already.
  -- 		 If buffer is new, It is added only.
  -- 		 If you move any buffer which has 1 distance from current buffer using bnext()/bprev()
  -- 		 it doesn't change stack order. and just navigated by stack order.
  sort = {
    method = nil,
    reverse = false,
  },

  -- where you cursor focus at buffer manager startup
  -- first : first line
  -- current : current buffer
  -- alternate : alternate buffer (if it doesn't exist, use current)
  focus = 'alternate',
})
```

</details>


# API

## 1) `toggle_manager()`

### Purpose

Toggle manager. After you executes this api, buffer_manager is opened. Again, It is closed.

### Usages

1) At startup, buffer manager is opened with normal mode,
	- In this mode, you can move cursor and reorder items using keys which is configured only.
	- You can reorder multiple files together if you use manual mode sorting method.
	- You cannot edit anything.
	- You can open buffer using shortcut which is highlighted.
2) After you press `toggle_edit` key, It turn on `edit_mode`.
	- Cursorline is removed as default.
	- You can edit the contents. (_but only line-wise removing is implemented now_).
	- After you removed specific lines, the result is applied and buffer is deleted
	  whenever you quit buffer manager while edit_mode or press `toggle_edit` to come back to normal mode.


## 2) `bnext()/bprev`

### Purpose

Go to next/previous buffer depends on sorting method among listed buffers.
These are similar with `:bnext` or `:bprev` as native neovim command.

### ❗ CAUTION ❗

For other sort method, buffer manager shows the buffer list in ascending order in case `reverse` is `false`.
It means that subordinate item is next buffer.

In `stack` sorting method, the newest item which is the last inserted is pushed on the top of buffer list.
After then, if other buffer is visited, the buffer is on the top. The older buffer is pushed down in the stack.

If you want to visit previous item which is visited before, you think bprev() function to go to them.
Typically, it selects the item at the top of the buffer list.
<u>As is commonly thought, stack sorting method borrows the method of keeping bprev() intact to return to the previous buffer.</u>


## 3) `get_bufcount()`

### Purpose

To get current buffer position information in buffer list depends on sorting method.
It is useful to integrate with statusline.

### Usages

Using [staline.nvim](https://github.com/tamton-aquib/staline.nvim), you can add this configuration.
```lua
sections = {
  right = {
    function() return vim.bo[0].fileencoding .. ' ' end ,
    ' ',
    -- 3:#2(4) => <bufnr>:#<index in buflist>(<total number of buflist>)
    function() return vim.api.nvim_get_current_buf() .. ':' .. require('bufman').get_bufcount() end,
    '  ',
    function() return vim.bo[0].filetype end,
    'right_sep_double',
    '-line_column'
  }
}
```



# Acknowledgements

This plugin is inspired by [j-morano/buffer_manager.nvim](https://github.com/j-morano/buffer_manager.nvim), [leath-dub/snipe.nvim](https://github.com/leath-dub/snipe.nvim)
