local M = {}

local compiled_registry = nil
local compiled_categories = nil
local is_compiled = false

function M.compile_registry()
    if is_compiled then return end
    
    local registry = require("freemason.registry")
    local start_time = vim.loop.hrtime()
    
    -- pre-process all tools for faster access
    local all_tools = registry.get_all()
    
    -- Extract categories
    local categories = {}
    local categories_set = {}
    for _, tool in ipairs(all_tools) do
        if tool.category and not categories_set[tool.category] then
            table.insert(categories, tool.category)
            categories_set[tool.category] = true
        end
    end
    table.sort(categories)
    
    -- Build optimized data structures
    local optimized_tools = {}
    local tools_by_name = {}
    local tools_by_category = {}
    
    for _, tool in ipairs(all_tools) do
        local optimized_tool = {
            name = tool.name,
            description = tool.description or "",
            homepage = tool.homepage or "",
            languages = tool.languages or {},
            category = tool.category or "other",
            executables = tool.executables or {},
            source = tool.source or "",
            display_name = tool.name,
            display_description = tool.description or "No description available",
            is_installed = false,
            installed_version = nil,
            needs_update = false,
        }
        
        table.insert(optimized_tools, optimized_tool)
        tools_by_name[tool.name] = optimized_tool
        
        local category = tool.category or "other"
        if not tools_by_category[category] then
            tools_by_category[category] = {}
        end
        table.insert(tools_by_category[category], optimized_tool)
    end
    
    local optimized_categories = {}
    for _, category in ipairs(categories) do
        table.insert(optimized_categories, category)
    end
    
    compiled_registry = {
        tools = optimized_tools,
        tools_by_name = tools_by_name,
        tools_by_category = tools_by_category,
        total_count = #optimized_tools
    }
    
    compiled_categories = optimized_categories
    is_compiled = true
    
    local end_time = vim.loop.hrtime()
    local compile_time = (end_time - start_time) / 1000000
    
    vim.notify(string.format("[Freemason] Registry ready (%d tools)", #optimized_tools), vim.log.levels.INFO)
end

-- Get all tools (instant access)
function M.get_all()
    if not is_compiled then
        M.compile_registry()
    end
    return compiled_registry.tools
end

-- Get tool by name (instant access)
function M.get(name)
    if not is_compiled then
        M.compile_registry()
    end
    return compiled_registry.tools_by_name[name]
end

-- Get categories (instant access)
function M.get_categories()
    if not is_compiled then
        M.compile_registry()
    end
    return compiled_categories
end

-- Get tools by category (instant access)
function M.get_by_category(category)
    if not is_compiled then
        M.compile_registry()
    end
    return compiled_registry.tools_by_category[category] or {}
end

-- Update tool status (for installer/UI)
function M.update_tool_status(name, is_installed, installed_version, needs_update)
    if not is_compiled then
        return
    end
    
    local tool = compiled_registry.tools_by_name[name]
    if tool then
        tool.is_installed = is_installed
        tool.installed_version = installed_version
        tool.needs_update = needs_update
    end
end

-- Get stats
function M.get_stats()
    if not is_compiled then
        return { compiled = false, total_tools = 0 }
    end
    
    return {
        compiled = true,
        total_tools = compiled_registry.total_count,
        categories = #compiled_categories
    }
end

-- Clear compiled data (for testing/debugging)
function M.clear()
    compiled_registry = nil
    compiled_categories = nil
    is_compiled = false
end

return M
