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
        -- Set default paths if not provided (relative to plugin directory)
        if not conf.registry.lspconfig_path then
            conf.registry.lspconfig_path = "./external/nvim-lspconfig/lsp"
        end
        if not conf.registry.mason_registry_path then
            conf.registry.mason_registry_path = "./external/mason-registry/packages"
        end
        
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
        vim.notify(
            "[Freemason] External repositories configured successfully. " ..
            "Full functionality available.",
            vim.log.levels.INFO
        )
    else
        vim.notify(
            "[Freemason] External repositories not configured. " ..
            "For full functionality, set up nvim-lspconfig and mason-registry. " ..
            "See README.md for instructions.",
            vim.log.levels.INFO
        )
    end
end

-- Return module
return M
