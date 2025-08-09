
local installer = require("freemason.installer")
local ui = require("freemason.ui")
local registry = require("freemason.registry_cache")

local M = {}

local function get_matching_tools(arg_lead)
    local completions = {}
    for _, tool in ipairs(registry.get_all()) do
        if tool.name:match("^" .. vim.pesc(arg_lead)) then
            table.insert(completions, tool.name)
        end
    end
    return completions
end

function M.register()
    vim.api.nvim_create_user_command("Freemason", function()
        ui.open()
    end, {
        desc = "Open Freemason UI",
    })

    vim.api.nvim_create_user_command("FreemasonInstall", function(opts)
        if not opts.args or opts.args == "" then
            vim.notify("[Freemason] Please provide a tool name to install", vim.log.levels.ERROR)
            return
        end
        
        vim.notify("[Freemason] Installing: " .. opts.args, vim.log.levels.INFO)
        installer.install(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return get_matching_tools(arg_lead)
        end,
        desc = "Install a tool",
    })

    vim.api.nvim_create_user_command("FreemasonUpdate", function(opts)
        if not opts.args or opts.args == "" then
            vim.notify("[Freemason] Please provide a tool name to update", vim.log.levels.ERROR)
            return
        end
        
        vim.notify("[Freemason] Updating: " .. opts.args, vim.log.levels.INFO)
        installer.update(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return get_matching_tools(arg_lead)
        end,
        desc = "Update a tool",
    })

    vim.api.nvim_create_user_command("FreemasonUninstall", function(opts)
        if not opts.args or opts.args == "" then
            vim.notify("[Freemason] Please provide a tool name to uninstall", vim.log.levels.ERROR)
            return
        end
        
        vim.notify("[Freemason] Uninstalling: " .. opts.args, vim.log.levels.INFO)
        installer.uninstall(opts.args)
    end, {
        nargs = 1,
        complete = function(arg_lead)
            return get_matching_tools(arg_lead)
        end,
        desc = "Uninstall a tool",
    })

    vim.api.nvim_create_user_command("FreemasonCache", function(opts)
        local registry_cache = require("freemason.registry_cache")
        if not registry_cache then
            vim.notify("[Freemason] Cache module not available", vim.log.levels.ERROR)
            return
        end
        
        if opts.args == "clear" then
            registry_cache.clear()
            vim.notify("[Freemason] All caches cleared", vim.log.levels.INFO)
        elseif opts.args == "stats" then
            local stats = registry_cache.get_cache_stats()
            vim.notify(string.format("[Freemason] Cache stats - Status cache: %d items", stats.status_cache_size), vim.log.levels.INFO)
        else
            vim.notify("[Freemason] Usage: FreemasonCache [clear|stats]", vim.log.levels.ERROR)
        end
    end, {
        nargs = "?",
        complete = function(arg_lead)
            if arg_lead == "" then
                return {"clear", "stats"}
            end
            return {}
        end,
        desc = "Manage Freemason cache (clear|stats)",
    })
end

return M
