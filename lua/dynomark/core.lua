local M = {}

local ns_id = vim.api.nvim_create_namespace("dynomark")

local dynomark_enabled = false

local function execute_dynomark_query(query)
    local handle = io.popen('dynomark --query "' .. query .. '"')
    local result = handle:read("*a")
    handle:close()
    return result:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
end

local function update_dynomark_blocks()
    if not dynomark_enabled then
        return
    end

    local parser = vim.treesitter.get_parser(0, "markdown")
    local tree = parser:parse()[1]
    local root = tree:root()

    local query = vim.treesitter.query.parse(
        "markdown",
        [[
        (fenced_code_block
            (info_string) @lang
            (#eq? @lang "dynomark")
            (code_fence_content) @content)
    ]]
    )

    for id, node in query:iter_captures(root, 0, 0, -1) do
        local name = query.captures[id]
        if name == "content" then
            local start_row, start_col, end_row, end_col = node:range()
            local content = vim.treesitter.get_node_text(node, 0)
            local result = execute_dynomark_query(content)

            -- Clear existing virtual text
            vim.api.nvim_buf_clear_namespace(0, ns_id, start_row, end_row + 1)

            -- Hide original content
            for i = start_row, end_row do
                local line = vim.fn.getline(i + 1)
                vim.api.nvim_buf_set_extmark(0, ns_id, i, 0, {
                    virt_text = { { string.rep(" ", #line), "Conceal" } },
                    virt_text_pos = "overlay",
                    hl_mode = "combine",
                })
            end

            -- Add new virtual text for results
            local lines = vim.split(result, "\n")
            for i, line in ipairs(lines) do
                local row = start_row + i - 1
                if row < end_row then
                    vim.api.nvim_buf_set_extmark(0, ns_id, row, 0, {
                        virt_text = { { line, "Comment" } },
                        virt_text_pos = "overlay",
                        hl_mode = "combine",
                    })
                elseif row == end_row then
                    -- Add remaining lines as virtual lines
                    local remaining_lines = vim.list_slice(lines, i)
                    vim.api.nvim_buf_set_extmark(0, ns_id, row - 1, 0, {
                        virt_lines = vim.tbl_map(function(l)
                            return { { l, "Comment" } }
                        end, remaining_lines),
                        virt_lines_above = false,
                    })
                    break
                end
            end

            -- Ensure the bottom fence is visible
            local bottom_fence = vim.fn.getline(end_row + 1)
            vim.api.nvim_buf_set_extmark(0, ns_id, end_row, 0, {
                virt_text = { { bottom_fence, "Comment" } },
                virt_text_pos = "overlay",
                hl_mode = "combine",
            })
        end
    end
end

function M.toggle_dynomark()
    dynomark_enabled = not dynomark_enabled
    if dynomark_enabled then
        update_dynomark_blocks()
        print("Dynomark enabled")
    else
        vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
        print("Dynomark disabled")
    end
end

function M.setup(opts)
    -- Any setup options can be handled here
    opts = opts or {}

    -- Create user commands
    -- vim.api.nvim_create_user_command("UpdateDynomark", update_dynomark_blocks, {})
    vim.api.nvim_create_user_command("ToggleDynomark", M.toggle_dynomark, {})

    -- Define a keymap for users to map in their own config
    vim.keymap.set("n", "<Plug>(ToggleDynomark)", function()
        M.toggle_dynomark()
    end, { noremap = true })

    -- Autocommands
    local function augroup(name)
        return vim.api.nvim_create_augroup("dynomark_" .. name, { clear = true })
    end

    vim.api.nvim_create_autocmd(
        { "FocusGained", "BufWritePost", "WinEnter", "BufEnter", "InsertLeave", "InsertEnter" },
        {
            pattern = "*.md",
            desc = "Update dynomark query results ",
            group = augroup("update_query_results"),
            callback = function()
                if dynomark_enabled then
                    update_dynomark_blocks()
                end
            end,
        }
    )
end

return M
