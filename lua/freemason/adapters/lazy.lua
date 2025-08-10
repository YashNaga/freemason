local M = {}

-- Lazy adapter state
local adapters_initialized = false
local initialization_in_progress = false
local initialization_callbacks = {}

-- Adapter instances (lazy loaded)
local lspconfig_adapter = nil
local mason_registry_adapter = nil

-- Configuration paths (set during setup)
local lspconfig_path = nil
local mason_registry_path = nil

--- Set the nvim-lspconfig path for lazy initialization
---@param path string
function M.set_lspconfig_path(path)
    lspconfig_path = path
end

--- Set the mason-registry path for lazy initialization
---@param path string
function M.set_mason_registry_path(path)
    mason_registry_path = path
end

--- Initialize adapters in background
---@param callback function|nil Optional callback when initialization completes
function M.initialize_adapters_async(callback)
    if adapters_initialized then
        if callback then
            callback()
        end
        return
    end
    
    if initialization_in_progress then
        if callback then
            table.insert(initialization_callbacks, callback)
        end
        return
    end
    
    initialization_in_progress = true
    
    -- Initialize in background
    vim.defer_fn(function()
        local success = M.initialize_adapters_sync()
        
        if success then
            adapters_initialized = true
        end
        
        initialization_in_progress = false
        
        -- Call all pending callbacks
        for _, cb in ipairs(initialization_callbacks) do
            pcall(cb)
        end
        initialization_callbacks = {}
        
        -- Call the current callback
        if callback then
            pcall(callback)
        end
    end, 10) -- Small delay to let UI render first
end

--- Initialize adapters synchronously (for when we need immediate access)
---@return boolean success
function M.initialize_adapters_sync()
    local success = true
    
    -- Initialize nvim-lspconfig adapter
    if lspconfig_path and not lspconfig_adapter then
        local ok, adapter = pcall(require, "freemason.adapters.lspconfig")
        if ok and adapter then
            adapter.set_lspconfig_path(lspconfig_path)
            lspconfig_adapter = adapter
            -- vim.notify("[Freemason] Loaded nvim-lspconfig", vim.log.levels.INFO)
        else
            success = false
            vim.notify("[Freemason] Failed to initialize nvim-lspconfig adapter", vim.log.levels.WARN)
        end
    end
    
    -- Initialize mason-registry adapter
    if mason_registry_path and not mason_registry_adapter then
        local ok, adapter = pcall(require, "freemason.adapters.mason_registry")
        if ok and adapter then
            adapter.set_registry_path(mason_registry_path)
            mason_registry_adapter = adapter
            -- vim.notify("[Freemason] Loaded mason-registry", vim.log.levels.INFO)
        else
            success = false
            vim.notify("[Freemason] Failed to initialize mason-registry adapter", vim.log.levels.WARN)
        end
    end
    
    return success
end

--- Get nvim-lspconfig adapter (lazy load if needed)
---@return table|nil
function M.get_lspconfig()
    if not adapters_initialized and not initialization_in_progress then
        M.initialize_adapters_sync()
    end
    return lspconfig_adapter
end

--- Get mason-registry adapter (lazy load if needed)
---@return table|nil
function M.get_mason_registry()
    if not adapters_initialized and not initialization_in_progress then
        M.initialize_adapters_sync()
    end
    return mason_registry_adapter
end

--- Check if adapters are initialized
---@return boolean
function M.is_initialized()
    return adapters_initialized
end

--- Check if initialization is in progress
---@return boolean
function M.is_initializing()
    return initialization_in_progress
end

return M
