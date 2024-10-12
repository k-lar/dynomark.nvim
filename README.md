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

https://github.com/user-attachments/assets/0183a34c-2146-465a-9b58-11aa5db1cecb

## Usage

- Use `:Dynomark toggle` to enable/disable Dynomark functionality.
- Use `:Dynomark run [vertical, horizontal, tab, float]` to run the query under the cursor (has to be in a fenced dynomark block) and an optional buffer type to open the results in.
    * Opens result of the query in a new buffer (by default a vertical split).
- Use `:Dynomark compile [vertical, horizontal, tab, float]` to combine your file with dynomark query results in place of the queries 
    * Opens compiled file in a new buffer (by default a vertical split).
- Map `<Plug>(DynomarkToggle)` to a key of your choice for quick toggling of the plugin.
- Map `<Plug>(DynomarkRun)` to a key of your choice quickly show the results of a query inside a
  new buffer (vertical/horizontal split or tab)

Examples for mapping both functions:

```lua
vim.keymap.set("n", "<leader>v", "<Plug>(DynomarkToggle)", { desc = "Toggle Dynomark" })
vim.keymap.set("n", "<leader>V", "<Plug>(DynomarkRun)", { desc = "Run dynomark query under cursor" })
```

## Configuration

Many lines of virtual text don't play well with cursors, especially when the cursor is on the top
or bottom of the screen. There's an experimental option `remap_arrows`, that tries to make scrolling
long query results better with arrow keys. This option is `false` by default.

```lua
{
    "k-lar/dynomark.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    opts = { -- Default values
        remap_arrows = false,
        results_view_location = "vertical", -- Can be "float", "tab", "vertical" or "horizontal"

        -- This is only used when results_view_location is "float"
        -- By default the window is placed in the upper right of the window
        -- If you want to have the window centered, set both offsets to 0.0
        float_horizontal_offset = 0.2,
        float_vertical_offset = 0.2,

        -- Turn this to true if you want the plugin to automatically download
        -- the dynomark engine if it's not found in your PATH.
        -- This is false by default!
        auto_download = false,
    },
}
```

## Planned features

- [X] Function to run and show only single queries
- [X] Option to show results in a floating window buffer
- [X] Open a new buffer that has results inserted in place of queries to allow saving "compiled" files

## Requirements

- Neovim >= 0.7.0
- [dynomark](https://github.com/k-lar/dynomark) must be installed and available in your PATH.
- Treesitter
- Markdown Treesitter parser

## BREAKING CHANGES

- `:ExecuteDynomark` command was replaced by `:Dynomark run [vertical, horizontal, float, tab]`
- `:ToggleDynomark` command was replaced by `:Dynomark toggle`
- `:CompileDynomark` command was replaced by `:Dynomark compile [vertical, horizontal, float, tab]`
- `<Plug>(ToggleDynomark)` has been replaced by `<Plug>(DynomarkToggle)`
- `<Plug>(ExecuteDynomark)` has been replaced by `<Plug>(DynomarkRun)`
