local M = {}

-- Cache for converted LSP configurations
local config_cache = {}

-- Path to nvim-lspconfig submodule (will be set when submodule is added)
local lspconfig_path = nil

--- Set the path to nvim-lspconfig submodule
---@param path string
function M.set_lspconfig_path(path)
    lspconfig_path = path
end

--- Get the path to nvim-lspconfig submodule
---@return string|nil
function M.get_lspconfig_path()
    return lspconfig_path
end

--- Load LSP configuration from nvim-lspconfig
---@param server_name string
---@return table|nil
local function load_lspconfig_data(server_name)
    if not lspconfig_path then
        -- Fallback to current system if submodule not available
        vim.notify("[Freemason] LSP config path not set", vim.log.levels.WARN)
        return nil
    end
    
    vim.notify("[Freemason] Loading LSP config for: " .. server_name .. " from path: " .. lspconfig_path, vim.log.levels.INFO)
    
    -- Try multiple possible paths for the config file
    local config_paths = {
        lspconfig_path .. "/lsp/" .. server_name .. ".lua",  -- Main LSP configs directory
        lspconfig_path .. "/lua/lspconfig/configs/" .. server_name .. ".lua",  -- Alternative location
        lspconfig_path .. "/" .. server_name .. ".lua",  -- Direct in root (fallback)
    }
    
    local config_file = nil
    for _, path in ipairs(config_paths) do
        local file = io.open(path, "r")
        if file then
            config_file = path
            file:close()
            break
        end
    end
    
    if not config_file then
        vim.notify("[Freemason] No config file found for: " .. server_name, vim.log.levels.WARN)
        return nil
    end
    
    vim.notify("[Freemason] Found config file: " .. config_file, vim.log.levels.INFO)
    
    local file = io.open(config_file, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Try to load the Lua file directly first (more reliable)
    local ok, config = pcall(function()
        -- Create a temporary environment to load the config
        local env = {}
        local func = load(content, "lspconfig_" .. server_name, "t", env)
        if func then
            func()
            -- Look for the configuration table
            for k, v in pairs(env) do
                if type(v) == "table" and v.cmd then
                    -- Clean the configuration to remove any non-serializable data
                    local clean_config = {}
                    for config_key, config_value in pairs(v) do
                        if type(config_value) == "string" or type(config_value) == "number" or type(config_value) == "boolean" then
                            clean_config[config_key] = config_value
                        elseif type(config_value) == "table" then
                            -- Recursively clean tables
                            local clean_table = {}
                            for table_key, table_value in pairs(config_value) do
                                if type(table_value) == "string" or type(table_value) == "number" or type(table_value) == "boolean" then
                                    clean_table[table_key] = table_value
                                elseif type(table_value) == "table" then
                                    -- Skip nested tables for now to avoid complexity
                                    clean_table[table_key] = {}
                                end
                            end
                            clean_config[config_key] = clean_table
                        end
                    end
                    return clean_config
                end
            end
        end
        return {}
    end)
    
    if ok and config and config.cmd then
        return config
    end
    
    -- Fallback to simple parsing if direct loading fails
    local config = {}
    
    -- Try to parse Lua table structure
    local cmd_match = content:match('cmd%s*=%s*{([^}]+)}')
    if cmd_match then
        local cmd_parts = {}
        for part in cmd_match:gmatch("'([^']+)'") do
            table.insert(cmd_parts, part)
        end
        config.cmd = cmd_parts
    end
    
    local filetypes_match = content:match('filetypes%s*=%s*{([^}]+)}')
    if filetypes_match then
        local filetypes_parts = {}
        for part in filetypes_match:gmatch("'([^']+)'") do
            table.insert(filetypes_parts, part)
        end
        config.filetypes = filetypes_parts
    end
    
    return config
end

--- Convert nvim-lspconfig format to Freemason format
---@param server_name string
---@param lspconfig_data table
---@return table
local function convert_lspconfig_format(server_name, lspconfig_data)
    local config = vim.deepcopy(lspconfig_data)
    
    -- Update binary paths for Freemason-installed tools
    if config.cmd then
        local tool_name = server_name
        if server_name == "lua_ls" then
            tool_name = "lua-language-server"
        elseif server_name == "tsserver" then
            tool_name = "typescript-language-server"
        end
        
        -- Check if the tool is installed by Freemason
        local lockfile = require("freemason.lockfile")
        if lockfile.is_listed(tool_name) then
            -- Update cmd to use Freemason binary path
            local bin_path = vim.fn.stdpath("data") .. "/freemason/bin/" .. tool_name
            if vim.fn.filereadable(bin_path) == 1 then
                config.cmd = {bin_path}
            end
        end
    end
    
    return {
        name = server_name,
        config = config,
        -- Add any additional Freemason-specific fields
        source = "nvim-lspconfig",
        categories = {"LSP"}
    }
end

--- Get LSP configuration for a server
---@param server_name string
---@return table|nil
function M.get(server_name)
    -- Check cache first
    if config_cache[server_name] then
        return config_cache[server_name]
    end
    
    -- Load from nvim-lspconfig
    local lspconfig_data = load_lspconfig_data(server_name)
    if not lspconfig_data then
        return nil
    end
    
    -- Convert to Freemason format
    local converted = convert_lspconfig_format(server_name, lspconfig_data)
    
    -- Cache the result
    config_cache[server_name] = converted
    return converted
end

--- Get all available LSP server names
---@return string[]
function M.get_all_server_names()
    if not lspconfig_path then
        return {}
    end
    
    local config_dir = lspconfig_path .. "/lua/lspconfig/server_configurations"
    local servers = {}
    
    -- This is a simplified implementation
    -- In production, you'd want to scan the directory properly
    local handle = io.popen("ls " .. config_dir .. "/*.lua 2>/dev/null")
    if handle then
        for file in handle:lines() do
            local server_name = file:match("([^/]+)%.lua$")
            if server_name then
                table.insert(servers, server_name)
            end
        end
        handle:close()
    end
    
    return servers
end

--- Clear the configuration cache
function M.clear_cache()
    config_cache = {}
end

return M
