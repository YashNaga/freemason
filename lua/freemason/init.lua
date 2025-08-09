local M = {}

-- Configuration
local config = require("freemason.config")

-- Initialize adapters
local adapters = require("freemason.adapters")

-- Setup function
function M.setup(opts)
    -- Apply user configuration
    config.setup(opts)
    
    -- Get configuration
    local conf = config.get()
    
    -- Set up external repository paths with smart defaults
    if conf.registry then
        -- Get the plugin directory (where this init.lua is located)
        local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:match("@?(.*/)"), ":h")
        
        -- If the path contains "lua/freemason", go up to the plugin root
        if plugin_dir:match("lua/freemason") then
            plugin_dir = vim.fn.fnamemodify(plugin_dir, ":h:h:h")
        end
        
        -- Only set absolute paths if user hasn't configured paths and relative paths don't work
        local function check_path_exists(path)
            return vim.fn.isdirectory(path) == 1
        end
        
        -- Check if relative paths work, if not, use absolute paths as fallback
        if not conf.registry.lspconfig_path or not check_path_exists(conf.registry.lspconfig_path) then
            local relative_path = "./external/nvim-lspconfig"
            local absolute_path = plugin_dir .. "/external/nvim-lspconfig"
            
            if check_path_exists(relative_path) then
                conf.registry.lspconfig_path = relative_path
            elseif check_path_exists(absolute_path) then
                conf.registry.lspconfig_path = absolute_path
            end
        end
        
        if not conf.registry.mason_registry_path or not check_path_exists(conf.registry.mason_registry_path) then
            local relative_path = "./external/mason-registry/packages"
            local absolute_path = plugin_dir .. "/external/mason-registry/packages"
            
            if check_path_exists(relative_path) then
                conf.registry.mason_registry_path = relative_path
            elseif check_path_exists(absolute_path) then
                conf.registry.mason_registry_path = absolute_path
            end
        end
        
        -- Debug: Show the configured paths
        vim.notify(string.format("[Freemason] Plugin directory: %s", plugin_dir), vim.log.levels.INFO)
        vim.notify(string.format("[Freemason] Mason-registry path: %s", conf.registry.mason_registry_path or "not configured"), vim.log.levels.INFO)
        vim.notify(string.format("[Freemason] Nvim-lspconfig path: %s", conf.registry.lspconfig_path or "not configured"), vim.log.levels.INFO)
        
        -- Set the paths in adapters
        adapters.set_lspconfig_path(conf.registry.lspconfig_path)
        adapters.set_mason_registry_path(conf.registry.mason_registry_path)
    end
    
    -- Register commands
    local commands = require("freemason.commands")
    commands.register()
    
    -- Set up LSP idle shutdown if enabled
    local launcher = require("freemason.launcher")
    if launcher and launcher.setup_idle_shutdown then
        launcher.setup_idle_shutdown()
    end
    
    -- Fire setup hook if enabled
    if conf.hooks and conf.hooks.enable then
        vim.api.nvim_exec_autocmds("User", { pattern = "FreemasonSetup" })
    end
    
    -- Show setup message based on external repository configuration
    if conf.registry and conf.registry.lspconfig_path and conf.registry.mason_registry_path then
        vim.notify("[Freemason] External repositories configured successfully. Full functionality available.", vim.log.levels.INFO)
    else
        vim.notify("[Freemason] External repositories not configured. For full functionality, set up nvim-lspconfig and mason-registry. See README.md for instructions.", vim.log.levels.INFO)
    end
end

-- Return module
return M
