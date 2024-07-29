# dynomark.nvim

A Neovim plugin for executing and displaying [Dynomark](https://github.com/k-lar/dynomark) queries in Markdown files.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "k-lar/dynomark.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    opts = {},
},
```

## Usage

- Use `:ToggleDynomark` to enable/disable Dynomark functionality.
- Map `<Plug>(ToggleDynomark)` to a key of your choice for quick toggling of the plugin.

Example for mapping the toggle function:

```lua
vim.keymap.set("n", "<leader>v", "<Plug>(ToggleDynomark)", { desc = "Toggle Dynomark" })
```

## Configuration

No additional configuration is required, but you can pass options to the setup function if needed in the future when this plugin receives updates.

```lua
require("dynomark").setup({
    -- options here (but there are none yet)
})
```

## Requirements

- Neovim >= 0.7.0
- [dynomark](https://github.com/k-lar/dynomark) must be installed and available in your PATH.
- Treesitter
- Markdown Treesitter parser

