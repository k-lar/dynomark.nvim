local M = {}

local config = {
    remap_arrows = false,
}

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
    -- Copy default config and merge with user opts if they exist
    config = vim.tbl_deep_extend("force", config, opts)

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

    local function check_cursor_proximity()
        if config.remap_arrows == false then
            return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local cursor_line = cursor[1] - 1 -- Convert to 0-based index

        -- Get all virtual text positions for the current buffer and namespace
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })

        -- Reset mappings to default
        vim.keymap.set("n", "<Up>", "k", { buffer = bufnr })
        vim.keymap.set("n", "<Down>", "j", { buffer = bufnr })

        -- Check if the cursor is near any virtual text
        for _, extmark in ipairs(extmarks) do
            local virt_text_line = extmark[2]
            local line_diff = cursor_line - virt_text_line

            if line_diff == 1 then
                -- Virtual text is above, map only Up key
                vim.keymap.set("n", "<Up>", "<C-y>", { buffer = bufnr, nowait = true })
            elseif line_diff == -1 then
                -- Virtual text is below, map only Down key
                vim.keymap.set("n", "<Down>", "<C-e>", { buffer = bufnr, nowait = true })
            end

            if math.abs(line_diff) == 1 then
                -- Set up an autocmd to reset mappings when the cursor moves away
                vim.api.nvim_create_autocmd("CursorMoved", {
                    buffer = bufnr,
                    once = true,
                    callback = function()
                        vim.keymap.set("n", "<Up>", "k", { buffer = bufnr })
                        vim.keymap.set("n", "<Down>", "j", { buffer = bufnr })
                    end,
                })

                return
            end
        end
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

    vim.api.nvim_create_autocmd("CursorMoved", {
        pattern = "*.md",
        desc = "Allow users to scroll when next to virtual text",
        group = augroup("cursor_in_virtualtext"),
        callback = function()
            check_cursor_proximity()
        end,
    })
end

return M
