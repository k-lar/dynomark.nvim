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

## Showcase

https://github.com/user-attachments/assets/15a5947d-bff3-4ef8-badf-2211c8d3c461

## Usage

- Use `:ToggleDynomark` to enable/disable Dynomark functionality.
- Use `:ExecuteDynomark` to run the query under the cursor (has to be in a fenced dynomark block).
    * Opens result of the query in a new buffer (by default a vertical split).
- Map `<Plug>(ToggleDynomark)` to a key of your choice for quick toggling of the plugin.
- Map `<Plug>(ExecuteDynomark)` to a key of your choice quickly show the results of a query inside a
  new buffer (vertical/horizontal split or tab)

Example for mapping the toggle function:

```lua
vim.keymap.set("n", "<leader>v", "<Plug>(ToggleDynomark)", { desc = "Toggle Dynomark" })
```

## Configuration

Many lines of virtual text don't play well with cursors, especially when the cursor is on the top
or bottom of the screen. There's an experimental option `remap_arrows`, that tries to make scrolling
long query results better with arrow keys. This option is `false` by default.

```lua
require("dynomark").setup({
    remap_arrows = false
    results_view_location = "vertical", -- can be "vertical", "horizontal" or "tab"
})
```

## Planned features

- [X] Function to run and show only single queries
- [ ] Show query results that are longer than the amount of lines on the screen in a virtual scrollable window
- [ ] Open a readonly/temp file that has results inserted in place of queries to allow saving "compiled" files

## Requirements

- Neovim >= 0.7.0
- [dynomark](https://github.com/k-lar/dynomark) must be installed and available in your PATH.
- Treesitter
- Markdown Treesitter parser

