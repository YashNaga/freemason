
local api = vim.api
local config = require("freemason.config")
local registry = require("freemason.registry_cache") -- Use cached registry
local installer = require("freemason.installer")

local M = {}

-- UI state variables
local ui_buf = nil
local ui_win = nil
local selected_category = "all"
local status_cache = {}
local expanded_tools = {}
local version_cache = {}
local status_checking_active = false

-- Setup custom highlight groups for Freemason UI
local function setup_highlights()
    -- Create a custom highlight group for section headers (bold and prominent)
    vim.api.nvim_set_hl(0, "FreemasonHeader", {
        bold = true,
        fg = vim.api.nvim_get_hl(0, {name = "Title"}).fg or 15, -- Use Title color or white
        cterm = {bold = true}
    })
end

-- Theme-aware highlight groups that automatically adapt to user's theme
local status_highlights = {
    installed = "String",           -- Green-like (success)
    update_available = "WarningMsg", -- Yellow-like (attention)
    not_installed = "ErrorMsg",     -- Red-like (error)
    pending = "WarningMsg",         -- Yellow-like (warning)
    loading = "Special"             -- Blue-like (info)
}

local function get_tools()
    local all_tools = registry.get_all()
    local filtered = {}

    for _, tool in ipairs(all_tools) do
        if not tool then
            goto continue
        end

        local categories = tool.categories or {}

        if selected_category ~= "all" and not vim.tbl_contains(categories, selected_category) then
            goto continue
        end

        table.insert(filtered, tool)
        ::continue::
    end

    table.sort(filtered, function(a, b)
        return a.name < b.name
    end)

    return filtered
end



-- Function to extract latest version from source ID
local function extract_latest_version(source_id)
    local version = source_id:match("@([^@]+)$")
    return version
end

-- Function to get installed version from lockfile
local function get_installed_version(tool_name)
    local lockfile = require("freemason.lockfile")
    local status = lockfile.get_status(tool_name)
    if status and status.version then
        return status.version
    end
    return nil
end

-- Function to compare versions (simple string comparison for now)
local function compare_versions(current, latest)
    if not current or not latest then
        return false
    end
    
    -- If current version is "latest", don't show update available
    if current == "latest" then
        return false
    end
    
    -- Remove 'v' prefix if present
    current = current:gsub("^v", "")
    latest = latest:gsub("^v", "")
    
    -- Simple string comparison (works for most version formats)
    return current ~= latest
end

-- Function to check if tool has updates available
local function check_for_updates(tool_name)
    local tool = registry.get(tool_name)
    if not tool or not tool.source or not tool.source.id then
        return false, nil, nil
    end
    
    local current_version = get_installed_version(tool_name)
    local latest_version = extract_latest_version(tool.source.id)
    
    if current_version and latest_version then
        local has_update = compare_versions(current_version, latest_version)
        return has_update, current_version, latest_version
    end
    
    return false, current_version, latest_version
end

-- Update tool status in compiled registry
local function update_tool_status(tool_name)
    local lockfile = require("freemason.lockfile")
    
    local status = lockfile.get_status(tool_name)
    local is_installed = status ~= nil
    local installed_version = is_installed and status.version or nil
    local needs_update = check_for_updates(tool_name)
    
    registry.update_tool_status(tool_name, is_installed, installed_version, needs_update)
end

-- Forward declaration for render function
local render

-- Background status checking function
local function check_tool_statuses_background(tools)
    local batch_size = 20 -- Process tools in batches
    local current_batch = 1
    local total_batches = math.ceil(#tools / batch_size)
    local updated = false
    
    local function process_batch()
        if current_batch > total_batches then
            -- All batches processed
            status_checking_active = false
            if updated then
                vim.schedule(function()
                    if ui_buf and api.nvim_buf_is_valid(ui_buf) then
                        render()
                    end
                end)
            end
            return
        end
        
        local start_idx = (current_batch - 1) * batch_size + 1
        local end_idx = math.min(current_batch * batch_size, #tools)
        
        for i = start_idx, end_idx do
            local tool = tools[i]
            if status_cache[tool.name] then goto continue end
            
            local status = installer.get_tool_status(tool.name) or "not_installed"
            if status == "installed" and check_for_updates(tool.name) then
                status_cache[tool.name] = "update_available"
                local _, current, latest = check_for_updates(tool.name)
                version_cache[tool.name] = { current = current, latest = latest }
            else
                status_cache[tool.name] = status
            end
            
            update_tool_status(tool.name)
            updated = true
            ::continue::
        end
        
        -- Update UI after each batch
        if updated then
            vim.schedule(function()
                if ui_buf and api.nvim_buf_is_valid(ui_buf) then
                    render()
                end
            end)
            updated = false
        end
        
        current_batch = current_batch + 1
        
        -- Process next batch with a small delay to keep UI responsive
        vim.defer_fn(process_batch, 50)
    end
    
    -- Start processing batches
    process_batch()
end

-- Function to get tool details for display
local function get_tool_details(tool_name)
    local tool = registry.get(tool_name)
    if not tool then
        return {}
    end
    
    local details = {}
    
    -- Description (handle multi-line descriptions)
    if tool.description then
        -- Split multi-line descriptions and format each line
        for line in tool.description:gmatch("[^\r\n]+") do
            -- Trim whitespace
            line = line:gsub("^%s*(.-)%s*$", "%1")
            if #line > 0 then
                table.insert(details, "    Description: " .. line)
            end
        end
    end
    
    -- Homepage
    if tool.homepage then
        table.insert(details, "    Homepage: " .. tool.homepage)
    end
    
    -- Languages
    if tool.languages and #tool.languages > 0 then
        table.insert(details, "    Languages: " .. table.concat(tool.languages, ", "))
    end
    
    -- Categories
    if tool.categories and #tool.categories > 0 then
        table.insert(details, "    Category: " .. table.concat(tool.categories, ", "))
    end
    
    -- Executables
    if tool.bin then
        local executables = {}
        for cmd, _ in pairs(tool.bin) do
            table.insert(executables, cmd)
        end
        if #executables > 0 then
            table.insert(details, "    Executables: " .. table.concat(executables, ", "))
        end
    end
    
    return details
end

-- Function to extract version from source ID
local function extract_latest_version(source_id)
    if not source_id then
        return nil
    end
    
    -- Extract version from patterns like:
    -- pkg:github/clangd/clangd@20.1.8
    -- pkg:pypi/black@25.1.0
    -- pkg:npm/typescript@5.3.3
    local version = source_id:match("@([^@]+)$")
    return version
end

-- Function to get installed version from lockfile
local function get_installed_version(tool_name)
    local lockfile = require("freemason.lockfile")
    local status = lockfile.get_status(tool_name)
    if status and status.version then
        return status.version
    end
    return nil
end

-- Function to compare versions (simple string comparison for now)
local function compare_versions(current, latest)
    if not current or not latest then
        return false
    end
    
    -- If current version is "latest", don't show update available
    if current == "latest" then
        return false
    end
    
    -- Remove 'v' prefix if present
    current = current:gsub("^v", "")
    latest = latest:gsub("^v", "")
    
    -- Simple string comparison (works for most version formats)
    return current ~= latest
end

render = function()
    if not ui_buf or not api.nvim_buf_is_valid(ui_buf) then return end

    local tools = get_tools()
    
    local lines = {}
    table.insert(lines, " 🧱 Freemason — Tool Manager")
    table.insert(lines, " " .. string.rep("─", 60))
    
            table.insert(lines, " Category: " .. selected_category .. "  |  Press i=install, u=update/uninstall, U=update all, r=refresh, q=quit, c=change category")
    table.insert(lines, " " .. string.rep("─", 60))
    table.insert(lines, "")
    
    -- Add highlighting for header elements (will be applied after buffer is set)
    local header_highlights = {
        {0, "Title"},      -- Title line
        {1, "Comment"},    -- Separator line  
        {2, "Special"},    -- Category line
        {3, "Comment"},    -- Separator line
    }
    
    -- Clear all existing highlights (tried different approaches, this works best)
    api.nvim_buf_clear_namespace(ui_buf, -1, 0, -1)

    local conf = config.get()
    local icons = (conf.ui and conf.ui.icons) or { 
        installed = "✓", 
        update_available = "↑",
        not_installed = "✗", 
        pending = "…",
        loading = "⏳"
    } 

    -- Collect highlights to apply after buffer is set
    local highlights_to_apply = {}

    -- Organize tools by status
    local tools_by_status = {
        installed = {},
        update_available = {},
        not_installed = {},
        pending = {},
        loading = {}
    }

    -- Categorize all tools (no limit)
    for _, tool in ipairs(tools) do
        local status = status_cache[tool.name] or "loading"
        table.insert(tools_by_status[status], tool)
    end

    -- Add installed tools section
    if #tools_by_status.installed > 0 then
        table.insert(lines, "")
        table.insert(lines, "INSTALLED")
        table.insert(lines, "")
        
        -- Add header highlight for "INSTALLED" section
        table.insert(highlights_to_apply, {#lines - 2, "FreemasonHeader", 0, -1})
        
        for _, tool in ipairs(tools_by_status.installed) do
            local icon = icons.installed or "✓"
            local version = tool.version and (" (" .. tool.version .. ")") or ""
            local line = string.format("  %s  %s%s", icon, tool.name, version)
            table.insert(lines, line)
            
            -- Store highlight info for later application
            local line_num = #lines
            local highlight_group = status_highlights.installed or "Normal"
            table.insert(highlights_to_apply, {line_num - 1, highlight_group, 2, 3})
            
            -- Add expanded details if tool is expanded
            if expanded_tools[tool.name] then
                local details = get_tool_details(tool.name)
                for _, detail_line in ipairs(details) do
                    table.insert(lines, detail_line)
                    -- Add highlight for detail lines (Comment color)
                    table.insert(highlights_to_apply, {#lines - 1, "Comment", 0, -1})
                end
            end
        end
    end

    -- Add update available tools section
    if #tools_by_status.update_available > 0 then
        table.insert(lines, "")
        table.insert(lines, "UPDATE AVAILABLE")
        table.insert(lines, "")
        
        -- Add header highlight for "UPDATE AVAILABLE" section
        table.insert(highlights_to_apply, {#lines - 2, "FreemasonHeader", 0, -1})
        
        for _, tool in ipairs(tools_by_status.update_available) do
            local icon = icons.update_available or "↑"
            local version_info = ""
            if version_cache[tool.name] then
                local current = version_cache[tool.name].current
                local latest = version_cache[tool.name].latest
                version_info = string.format(" (%s → %s)", current, latest)
            end
            local line = string.format("  %s  %s%s", icon, tool.name, version_info)
            table.insert(lines, line)
            
            -- Store highlight info for later application
            local line_num = #lines
            local highlight_group = status_highlights.update_available or "Normal"
            table.insert(highlights_to_apply, {line_num - 1, highlight_group, 2, 3})
            
            -- Add expanded details if tool is expanded
            if expanded_tools[tool.name] then
                local details = get_tool_details(tool.name)
                for _, detail_line in ipairs(details) do
                    table.insert(lines, detail_line)
                    -- Add highlight for detail lines (Comment color)
                    table.insert(highlights_to_apply, {#lines - 1, "Comment", 0, -1})
                end
            end
        end
    end

    -- Add not installed tools section
    if #tools_by_status.not_installed > 0 then
        table.insert(lines, "")
        table.insert(lines, "NOT INSTALLED")
        table.insert(lines, "")
        
        -- Add header highlight for "NOT INSTALLED" section
        table.insert(highlights_to_apply, {#lines - 2, "FreemasonHeader", 0, -1})
        
        for _, tool in ipairs(tools_by_status.not_installed) do
            local icon = icons.not_installed or "✗"
            local version = tool.version and (" (" .. tool.version .. ")") or ""
            local line = string.format("  %s  %s%s", icon, tool.name, version)
            table.insert(lines, line)
            
            -- Store highlight info for later application
            local line_num = #lines
            local highlight_group = status_highlights.not_installed or "Normal"
            table.insert(highlights_to_apply, {line_num - 1, highlight_group, 2, 3})
            
            -- Add expanded details if tool is expanded
            if expanded_tools[tool.name] then
                local details = get_tool_details(tool.name)
                for _, detail_line in ipairs(details) do
                    table.insert(lines, detail_line)
                    -- Add highlight for detail lines (Comment color)
                    table.insert(highlights_to_apply, {#lines - 1, "Comment", 0, -1})
                end
            end
        end
    end

    -- Add pending tools section (if any)
    if #tools_by_status.pending > 0 then
        table.insert(lines, "")
        table.insert(lines, "PENDING")
        table.insert(lines, "")
        
        -- Add header highlight for "PENDING" section
        table.insert(highlights_to_apply, {#lines - 2, "FreemasonHeader", 0, -1})
        
        for _, tool in ipairs(tools_by_status.pending) do
            local icon = icons.pending or "…"
            local version = tool.version and (" (" .. tool.version .. ")") or ""
            local line = string.format("  %s  %s%s", icon, tool.name, version)
            table.insert(lines, line)
            
            -- Store highlight info for later application
            local line_num = #lines
            local highlight_group = status_highlights.pending or "Normal"
            table.insert(highlights_to_apply, {line_num - 1, highlight_group, 2, 3})
            
            -- Add expanded details if tool is expanded
            if expanded_tools[tool.name] then
                local details = get_tool_details(tool.name)
                for _, detail_line in ipairs(details) do
                    table.insert(lines, detail_line)
                    -- Add highlight for detail lines (Comment color)
                    table.insert(highlights_to_apply, {#lines - 1, "Comment", 0, -1})
                end
            end
        end
    end

    -- Add loading tools section (if any)
    if #tools_by_status.loading > 0 then
        table.insert(lines, "")
        table.insert(lines, "LOADING")
        table.insert(lines, "")
        
        -- Add header highlight for "LOADING" section
        table.insert(highlights_to_apply, {#lines - 2, "FreemasonHeader", 0, -1})
        
        for _, tool in ipairs(tools_by_status.loading) do
            local icon = icons.loading or "⏳"
            local version = tool.version and (" (" .. tool.version .. ")") or ""
            local line = string.format("  %s  %s%s", icon, tool.name, version)
            table.insert(lines, line)
            
            -- Store highlight info for later application
            local line_num = #lines
            local highlight_group = status_highlights.loading or "Normal"
            table.insert(highlights_to_apply, {line_num - 1, highlight_group, 2, 3})
            
            -- Add expanded details if tool is expanded
            if expanded_tools[tool.name] then
                local details = get_tool_details(tool.name)
                for _, detail_line in ipairs(details) do
                    table.insert(lines, detail_line)
                    -- Add highlight for detail lines (Comment color)
                    table.insert(highlights_to_apply, {#lines - 1, "Comment", 0, -1})
                end
            end
        end
    end
    
    -- Start background status checking if not already running
    if not status_checking_active then
        status_checking_active = true
        vim.defer_fn(function()
            check_tool_statuses_background(tools)
        end, 100) -- Slight delay to let UI render first
    end
    
    -- Show total tool count
    table.insert(lines, "")
    table.insert(lines, string.format("Total: %d tools", #tools))

    -- Set buffer content (had issues with this at first)
    api.nvim_buf_set_option(ui_buf, "modifiable", true)
    api.nvim_buf_set_lines(ui_buf, 0, -1, false, lines)
    api.nvim_buf_set_option(ui_buf, "modifiable", false)
    
    -- Apply header highlighting
    for _, highlight in ipairs(header_highlights) do
        local line_num, group = highlight[1], highlight[2]
        api.nvim_buf_add_highlight(ui_buf, -1, group, line_num, 0, -1)
    end
    
    -- Apply tool highlights
    for _, highlight in ipairs(highlights_to_apply) do
        local line_num, group, start_col, end_col = highlight[1], highlight[2], highlight[3], highlight[4]
        api.nvim_buf_add_highlight(ui_buf, -1, group, line_num, start_col, end_col)
    end
end

local function create_window()
    -- Setup custom highlights
    setup_highlights()
    
    -- Create a new buffer
    ui_buf = api.nvim_create_buf(false, true)
    
    -- Calculate window dimensions
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    -- Create floating window
    ui_win = api.nvim_open_win(ui_buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        border = "rounded",
        style = "minimal",
    })

    -- Set buffer options
    api.nvim_buf_set_option(ui_buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(ui_buf, "buftype", "nofile")
    api.nvim_buf_set_option(ui_buf, "swapfile", false)
    api.nvim_buf_set_option(ui_buf, "modifiable", false)
    api.nvim_buf_set_name(ui_buf, "Freemason")
    api.nvim_buf_set_option(ui_buf, "filetype", "freemason")

    -- Render content
    render()
    
    -- Set cursor position to first tool entry (after headers)
    -- I like this better than starting at the top
    api.nvim_win_set_cursor(ui_win, {5, 0})
    
    -- Set keymaps using a different approach
    local function set_keymaps()
        -- Check if buffer is still valid
        if not api.nvim_buf_is_valid(ui_buf) then
            return
        end
        
        -- Clear existing keymaps
        api.nvim_buf_set_keymap(ui_buf, "n", "i", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "u", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "U", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "r", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "q", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "c", "", {})
        api.nvim_buf_set_keymap(ui_buf, "n", "<CR>", "", {})
        
        -- Set new keymaps (had to use this approach instead of the simpler one)
                         api.nvim_buf_set_keymap(ui_buf, "n", "i", "", {
            callback = function()
                if not api.nvim_buf_is_valid(ui_buf) then
                    return
                end
                 local line = api.nvim_get_current_line()
                 -- Updated pattern to work with indented format: "  ✓  toolname"
                 local name = line:match("^%s+%S+%s+(%S+)")
                 if name then
                     vim.notify("[Freemason] Installing: " .. name, vim.log.levels.INFO)
                     -- Show pending status immediately for visual feedback
                     status_cache[name] = "pending"
                     render()
                     -- Start installation
                     installer.install(name)
                     -- Update status cache after installation
                                             vim.defer_fn(function()
                            if api.nvim_buf_is_valid(ui_buf) then
                                status_cache[name] = "installed"
                                render()
                            end
                        end, 100)
                 end
             end,
             noremap = true,
             silent = true
         })
        
                 api.nvim_buf_set_keymap(ui_buf, "n", "u", "", {
             callback = function()
                 if not api.nvim_buf_is_valid(ui_buf) then
                     return
                 end
                 local line = api.nvim_get_current_line()
                 -- Updated pattern to work with indented format: "  ✓  toolname"
                 local name = line:match("^%s+%S+%s+(%S+)")
                 if name then
                     local status = status_cache[name]
                     if status == "update_available" then
                         -- Update the tool
                         vim.notify("[Freemason] Updating: " .. name, vim.log.levels.INFO)
                         status_cache[name] = "pending"
                         render()
                         installer.update(name)
                         -- Update status cache after update
                                                 vim.defer_fn(function()
                            if api.nvim_buf_is_valid(ui_buf) then
                                status_cache[name] = "installed"
                                version_cache[name] = nil
                                render()
                            end
                        end, 100)
                     else
                         -- Uninstall the tool
                         vim.notify("[Freemason] Uninstalling: " .. name, vim.log.levels.INFO)
                         status_cache[name] = "pending"
                         render()
                         installer.uninstall(name)
                         -- Update status cache after uninstallation
                                                 vim.defer_fn(function()
                            if api.nvim_buf_is_valid(ui_buf) then
                                status_cache[name] = "not_installed"
                                render()
                            end
                        end, 100)
                     end
                 end
             end,
             noremap = true,
             silent = true
         })
        
        api.nvim_buf_set_keymap(ui_buf, "n", "r", "", {
            callback = function()
                vim.notify("[Freemason] Refreshing...", vim.log.levels.INFO)
                status_cache = {}
                expanded_tools = {} -- Clear expanded state when refreshing
                status_checking_active = false -- Reset status checking
                render()
            end,
            noremap = true,
            silent = true
        })
        
        api.nvim_buf_set_keymap(ui_buf, "n", "q", "", {
            callback = function()
                vim.cmd("close")
            end,
            noremap = true,
            silent = true
        })
        
        api.nvim_buf_set_keymap(ui_buf, "n", "c", "", {
            callback = function()
                local categories = { "all", "LSP", "Formatter", "Linter", "DAP" }
                local current_index = 1
                for i, cat in ipairs(categories) do
                    if cat == selected_category then
                        current_index = i
                        break
                    end
                end
                current_index = current_index + 1
                if current_index > #categories then current_index = 1 end
                selected_category = categories[current_index]
                vim.notify("[Freemason] Category: " .. selected_category, vim.log.levels.INFO)
                expanded_tools = {} -- Clear expanded state when changing categories
                render()
                -- Auto-scroll to top when category changes
                vim.defer_fn(function()
                    if ui_win and api.nvim_win_is_valid(ui_win) then
                        api.nvim_win_set_cursor(ui_win, {5, 0})  -- Line 5 is first tool entry
                    end
                end, 50)  -- Small delay to ensure render is complete
            end,
            noremap = true,
            silent = true
        })
        
        -- U key to update all tools with updates available
        api.nvim_buf_set_keymap(ui_buf, "n", "U", "", {
            callback = function()
                local tools_to_update = {}
                for name, status in pairs(status_cache) do
                    if status == "update_available" then
                        table.insert(tools_to_update, name)
                    end
                end
                
                if #tools_to_update == 0 then
                    vim.notify("[Freemason] No tools need updating", vim.log.levels.INFO)
                    return
                end
                
                vim.notify("[Freemason] Updating " .. #tools_to_update .. " tools...", vim.log.levels.INFO)
                
                -- Update all tools with updates available
                for i, name in ipairs(tools_to_update) do
                    status_cache[name] = "pending"
                    installer.update(name)
                    
                    -- Update status after a delay
                    vim.defer_fn(function()
                        status_cache[name] = "installed"
                        version_cache[name] = nil
                        render()
                    end, 100 * i) -- Stagger updates
                end
            end,
            noremap = true,
            silent = true
        })
        
        -- Enter key to toggle tool details
        api.nvim_buf_set_keymap(ui_buf, "n", "<CR>", "", {
            callback = function()
                local line = api.nvim_get_current_line()
                -- Check if we're on a tool line (indented with icon)
                local name = line:match("^%s+%S+%s+(%S+)")
                if name then
                    -- Toggle expanded state
                    expanded_tools[name] = not expanded_tools[name]
                    render()
                    -- Keep cursor on the same tool
                    vim.defer_fn(function()
                        if ui_win and api.nvim_win_is_valid(ui_win) then
                            local current_line = api.nvim_win_get_cursor(ui_win)[1] - 1
                            api.nvim_win_set_cursor(ui_win, {current_line + 1, 0})
                        end
                    end, 50)
                end
            end,
            noremap = true,
            silent = true
        })
        

    end
    
    -- Set keymaps after a short delay
    vim.defer_fn(set_keymaps, 100)
end

function M.open()
    if ui_buf and api.nvim_buf_is_valid(ui_buf) then
        api.nvim_set_current_buf(ui_buf)
        api.nvim_set_current_win(ui_win)
    else
        create_window()
    end
end

-- Refresh the UI (for progressive loading)
function M.refresh()
                    if ui_buf and api.nvim_buf_is_valid(ui_buf) and ui_win and api.nvim_win_is_valid(ui_win) then
        render()
    end
end

return M
