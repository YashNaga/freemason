local M = {}

local compiled_registry = require("freemason.registry_compiler")

local status_cache = {}
local status_cache_timestamps = {}
local CACHE_TTL = 600

local function ensure_compiled()
    -- This was tricky - had to check if already compiled first
    if compiled_registry.get_stats().compiled then return end
            -- vim.notify("[Freemason] Compiling registry...", vim.log.levels.INFO)
    compiled_registry.compile_registry()
end

function M.get_all()
    ensure_compiled()
    return compiled_registry.get_all()
end

function M.get(name)
    ensure_compiled()
    return compiled_registry.get(name)
end

function M.get_categories()
    ensure_compiled()
    return compiled_registry.get_categories()
end

function M.get_by_category(category)
    ensure_compiled()
    return compiled_registry.get_by_category(category)
end

local function is_cache_valid(key)
    local timestamp = status_cache_timestamps[key]
    if not timestamp then return false end
    return (vim.loop.hrtime() - timestamp) < (CACHE_TTL * 1000000000)
end

function M.get_tool_status(tool_name)
    if is_cache_valid(tool_name) then
        return status_cache[tool_name]
    end
    return nil
end

function M.set_tool_status(tool_name, status_data)
    status_cache[tool_name] = status_data
    status_cache_timestamps[tool_name] = vim.loop.hrtime()
end

-- Update tool status in compiled registry
function M.update_tool_status(tool_name, is_installed, installed_version, needs_update)
    compiled_registry.update_tool_status(tool_name, is_installed, installed_version, needs_update)
    -- Also update cache
    M.set_tool_status(tool_name, {
        is_installed = is_installed,
        installed_version = installed_version,
        needs_update = needs_update
    })
end

-- Invalidate specific tool cache
function M.invalidate_tool(tool_name)
    status_cache[tool_name] = nil
    status_cache_timestamps[tool_name] = nil
end

-- Invalidate all status cache
function M.invalidate_all()
    status_cache = {}
    status_cache_timestamps = {}
end

-- Get cache stats
function M.get_cache_stats()
    local cache_size = 0
    for _ in pairs(status_cache) do
        cache_size = cache_size + 1
    end
    
    return {
        status_cache_size = cache_size,
        compiled_registry_stats = compiled_registry.get_stats()
    }
end

-- Clear all data (for testing)
function M.clear()
    M.invalidate_all()
    compiled_registry.clear()
end

return M
