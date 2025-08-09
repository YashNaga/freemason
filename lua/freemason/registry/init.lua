local M = {}

local yaml = require("freemason.utils").yaml
local Path = require("freemason.utils").Path

-- Try to use adapter first, fallback to local data
local adapters_ok, adapters = pcall(require, "freemason.adapters")

--- Get a tool by name
---@param name string
---@return table|nil
function M.get(name)
    -- Try adapter first (lazy loaded)
    if adapters_ok and adapters then
        local adapter = adapters.mason_registry()
        if adapter then
            local adapter_data = adapter.get(name)
            if adapter_data then
                -- Convert adapter data to freemason format
                return {
                    name = adapter_data.name or name,
                    description = adapter_data.description or "",
                    homepage = adapter_data.homepage or "",
                    languages = adapter_data.languages or {},
                    categories = adapter_data.categories or {},
                    executables = adapter_data.executables or {},
                    source = adapter_data.source, -- Include source information for installation
                    source_type = "mason_registry"
                }
            end
        end
    end
    
    -- Fallback to local package.yaml
    local package_path = Path:new(vim.fn.stdpath("config")):join("lua", "freemason", "registry", "packages", name, "package.yaml")
    
    if package_path:exists() then
        local content = package_path:read()
        local package_data = yaml.parse(content)
        
        if package_data then
            return {
                name = package_data.name or name,
                description = package_data.description or "",
                homepage = package_data.homepage or "",
                languages = package_data.languages or {},
                categories = package_data.categories or {},
                executables = package_data.executables or {},
                source_type = "local"
            }
        end
    end
    
    return nil
end

--- Get all available tools
---@return table[]
function M.get_all()
    local tools = {}
    
    -- Try to get package names from adapter first (lazy loaded)
    if adapters_ok and adapters then
        local adapter = adapters.mason_registry()
        if adapter then
            local package_names = adapter.get_all_package_names()
            if package_names and #package_names > 0 then
                for _, name in ipairs(package_names) do
                    local tool = M.get(name)
                    if tool then
                        table.insert(tools, tool)
                    end
                end
            else
                -- Debug: Check if adapter path is correct
                vim.notify("[Freemason] No packages found in mason-registry adapter", vim.log.levels.WARN)
            end
        else
            vim.notify("[Freemason] Mason-registry adapter not available", vim.log.levels.WARN)
        end
    else
        vim.notify("[Freemason] Adapters not available", vim.log.levels.WARN)
    end
    
    return tools
end

return M
