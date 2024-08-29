local M = {}

local config = {
    remap_arrows = false,
    results_view_location = "vertical",
    float_horizontal_offset = 0.2,
    float_vertical_offset = 0.2,
}

local ns_id = vim.api.nvim_create_namespace("dynomark")
local dynomark_enabled = false
local dynomark_exists = vim.fn.executable("dynomark") == 1

local dynomark_query = [[
    (fenced_code_block
        (info_string) @lang
        (#eq? @lang "dynomark")
        (code_fence_content) @content)
]]

local function get_view_location(arg)
    local valid_locations = { "tab", "vertical", "horizontal", "float" }
    if arg and vim.tbl_contains(valid_locations, arg) then
        return arg
    end
    return config.results_view_location
end

function M.run_dynomark(args)
    if not args or not args.fargs or #args.fargs < 1 then
        M.execute_current_dynomark_block()
        return
    else
        local view_location = get_view_location(args.fargs[1])
        local old_view_location = config.results_view_location
        config.results_view_location = view_location
        M.execute_current_dynomark_block()
        config.results_view_location = old_view_location
    end
end

function M.compile_dynomark(args)
    local view_location = get_view_location(args.fargs[1])
    local old_view_location = config.results_view_location
    config.results_view_location = view_location
    M.execute_all_dynomark_blocks()
    config.results_view_location = old_view_location
end

local function create_dynomark_command()
    vim.api.nvim_create_user_command("Dynomark", function(args)
        local subcommand = args.fargs[1]
        if subcommand == "run" then
            M.run_dynomark({ fargs = { args.fargs[2] } })
        elseif subcommand == "compile" then
            M.compile_dynomark({ fargs = { args.fargs[2] } })
        elseif subcommand == "toggle" then
            M.toggle_dynomark()
        else
            vim.notify("Invalid Dynomark subcommand. Use 'run', 'compile', or 'toggle'.", vim.log.levels.ERROR)
        end
    end, {
        nargs = "+",
        complete = function(_, cmdline)
            local args = vim.split(cmdline, "%s+")
            if #args == 2 then
                return { "run", "compile", "toggle" }
            elseif #args == 3 and (args[2] == "run" or args[2] == "compile") then
                return { "tab", "vertical", "horizontal", "float" }
            end
            return {}
        end,
    })
end

local function query_dynomark_blocks(callback)
    local parser = vim.treesitter.get_parser(0, "markdown")
    local tree = parser:parse()[1]
    local root = tree:root()

    local query = vim.treesitter.query.parse("markdown", dynomark_query)

    for id, node in query:iter_captures(root, 0, 0, -1) do
        local name = query.captures[id]
        if name == "content" then
            callback(node)
        end
    end
end

local function execute_dynomark_query(query)
    if not dynomark_exists then
        vim.notify("Dynomark is not installed. Please install it to use this plugin", vim.log.levels.ERROR)
        dynomark_enabled = false
        return ""
    end

    -- 2>&1 to redirect errors from stderr to stdout, because io.popen can't read stderr for some reason
    local handle = io.popen("dynomark --query '" .. query .. "' 2>&1")
    if not handle then
        vim.notify("Failed to execute dynomark command", vim.log.levels.ERROR)
        return ""
    end

    local result = handle:read("*a")
    handle:close()
    return result:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
end

local function get_content_dimensions(content)
    local lines = vim.split(content, "\n")
    local height = #lines
    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, #line)
    end
    return height, width
end

local function create_float_window(content)
    local content_height, content_width = get_content_dimensions(content)

    local min_height = 10
    local max_height = math.floor(vim.o.lines * 0.8)
    local min_width = 30
    local max_width = math.floor(vim.o.columns * 0.8)

    local height = math.max(min_height, math.min(content_height, max_height))
    local width = math.max(min_width, math.min(content_width, max_width))

    -- Calculate row to center the window vertically
    local row = math.floor((vim.o.lines * (0.5 + config.float_vertical_offset) - height) / 2)

    -- Calculate col to position the window horizontally with the offset
    local col = math.floor(vim.o.columns * (0.5 + config.float_horizontal_offset) - width / 2)

    -- Ensure the window stays within the screen boundaries
    row = math.max(0, math.min(row, vim.o.lines - height))
    col = math.max(0, math.min(col, vim.o.columns - width))

    local opts = {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
    }

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, opts)

    return buf, win
end

local function setup_results_buffer(result, buf_name)
    buf_name = buf_name or "dynomark_results"
    local buf, win

    if config.results_view_location == "float" then
        buf, win = create_float_window(result)
    else
        buf = vim.api.nvim_get_current_buf()
    end

    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
end

local function update_dynomark_blocks()
    if not dynomark_enabled then
        return
    end

    query_dynomark_blocks(function(node)
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
    end)
end

function M.toggle_dynomark()
    dynomark_enabled = not dynomark_enabled
    if dynomark_enabled then
        update_dynomark_blocks()
        vim.notify("Dynomark enabled", vim.log.levels.INFO, { title = "Dynomark" })
    else
        vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
        vim.notify("Dynomark disabled", vim.log.levels.INFO, { title = "Dynomark" })
    end
end

function M.is_cursor_in_dynomark_block()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]

    local result = nil
    query_dynomark_blocks(function(node)
        local start_row, start_col, end_row, end_col = node:range()
        if
            (row > start_row and row < end_row)
            or (row == start_row and col >= start_col)
            or (row == end_row and col <= end_col)
        then
            result = node
        end
    end)
    return result
end

function M.execute_current_dynomark_block()
    local node = M.is_cursor_in_dynomark_block()
    if not node then
        vim.notify("Cursor is not inside a dynomark code block", vim.log.levels.INFO, { title = "Dynomark" })
        return
    end

    local content = vim.treesitter.get_node_text(node, 0)
    local result = execute_dynomark_query(content)

    -- Create a new window based on configuration
    local results_view_table = {
        vertical = "vnew",
        horizontal = "new",
        tab = "tabnew",
        float = function() end, -- Do nothing here, as we handle float separately
    }

    local cmd = results_view_table[config.results_view_location]
    if type(cmd) == "string" then
        vim.cmd(cmd)
    end

    setup_results_buffer(result)
end

function M.execute_all_dynomark_blocks()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local new_lines = {}
    local in_dynomark_block = false
    local current_block = {}
    -- TODO: Keep this for now, maybe add config option to allow compiling with
    -- dynomark fence lines kept intact
    local fence_line = ""

    for _, line in ipairs(lines) do
        if line:match("^```dynomark") then
            in_dynomark_block = true
            fence_line = line
            current_block = {}
        elseif in_dynomark_block and line:match("^```%s*$") then
            in_dynomark_block = false
            local content = table.concat(current_block, "\n")
            local result = execute_dynomark_query(content)
            -- table.insert(new_lines, fence_line)
            for _, result_line in ipairs(vim.split(result, "\n")) do
                table.insert(new_lines, result_line)
            end
            -- table.insert(new_lines, line)
        elseif in_dynomark_block then
            table.insert(current_block, line)
        else
            table.insert(new_lines, line)
        end
    end

    -- Create a new buffer with the processed content
    local results_view_table = {
        vertical = "vnew",
        horizontal = "new",
        tab = "tabnew",
        float = function() end,
    }

    local cmd = results_view_table[config.results_view_location]
    if type(cmd) == "string" then
        vim.cmd(cmd)
    end

    setup_results_buffer(table.concat(new_lines, "\n"), "dynomark_compiled")

    vim.notify("All dynomark blocks processed", vim.log.levels.INFO, { title = "Dynomark" })
end

function M.setup(opts)
    -- Copy default config and merge with user opts if they exist
    config = vim.tbl_deep_extend("force", config, opts)

    -- Create user commands
    create_dynomark_command()

    -- Define a keymap for users to map in their own config
    vim.keymap.set("n", "<Plug>(DynomarkToggle)", function()
        M.toggle_dynomark()
    end, { noremap = true })
    vim.keymap.set("n", "<Plug>(DynomarkRun)", function()
        M.run_dynomark({})
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
