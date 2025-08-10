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
        
        -- If we're in a plugin manager directory (like lazy), find the actual plugin directory
        if plugin_dir:match("/lazy$") or plugin_dir:match("/packer$") or plugin_dir:match("/plugged$") then
            -- Look for the freemason directory within the plugin manager directory
            local freemason_dir = plugin_dir .. "/freemason"
            if vim.fn.isdirectory(freemason_dir) == 1 then
                plugin_dir = freemason_dir
            end
        end
        
        -- Set paths if not already configured by user
        if not conf.registry.lspconfig_path then
            conf.registry.lspconfig_path = plugin_dir .. "/external/nvim-lspconfig"
        end
        
        if not conf.registry.mason_registry_path then
            conf.registry.mason_registry_path = plugin_dir .. "/external/mason-registry/packages"
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
    
    -- Register installed LSPs on startup
    if launcher and launcher.register_installed_lsps then
        launcher.register_installed_lsps()
    end
    
    -- Set up LSP keymaps if enabled
    if conf.lsp and conf.lsp.keymaps then
        local keymaps = require("freemason.lsp.keymaps")
        keymaps.setup_autocmd(conf.lsp.keymaps)
    end
    
    -- Set up diagnostics if enabled
    if conf.lsp and conf.lsp.diagnostics then
        local diagnostics = conf.lsp.diagnostics
        if diagnostics.enabled then
            -- Configure diagnostic signs
            if diagnostics.signs and diagnostics.signs.enabled then
                for severity, icon in pairs(diagnostics.signs.text) do
                    vim.fn.sign_define('DiagnosticSign' .. severity, {
                        text = icon,
                        texthl = 'DiagnosticSign' .. severity,
                    })
                end
            end
            
            -- Configure diagnostic virtual text
            if diagnostics.virtual_text then
                vim.diagnostic.config({
                    virtual_text = diagnostics.virtual_text,
                    underline = diagnostics.underline or { enabled = true },
                    signs = diagnostics.signs and diagnostics.signs.enabled or true,
                    severity_sort = diagnostics.severity_sort or true,
                })
            end
        end
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
