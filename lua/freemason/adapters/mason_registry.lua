local M = {}

-- Cache for converted package data
local package_cache = {}

-- Path to mason-registry submodule (will be set when submodule is added)
local registry_path = nil

--- Set the path to mason-registry submodule
---@param path string
function M.set_registry_path(path)
    registry_path = path
end

--- Get the path to mason-registry submodule
---@return string|nil
function M.get_registry_path()
    return registry_path
end

--- Load package data from mason-registry
---@param package_name string
---@return table|nil
local function load_package_data(package_name)
    if not registry_path then
        -- Fallback to current system if submodule not available
        return nil
    end
    
    -- Try multiple possible paths for the package file
    local package_paths = {
        registry_path .. "/packages/" .. package_name .. "/package.yaml",
        registry_path .. "/" .. package_name .. "/package.yaml",
        registry_path .. "/packages/" .. package_name .. ".yaml"
    }
    
    local package_file = nil
    for _, path in ipairs(package_paths) do
        local file = io.open(path, "r")
        if file then
            package_file = path
            file:close()
            break
        end
    end
    
    if not package_file then
        return nil
    end
    
    local file = io.open(package_file, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Use the existing YAML parser from freemason.utils
    local yaml_utils = require("freemason.utils")
    local package_data = yaml_utils.yaml.parse(content)
    
    if package_data then
        return package_data
    end
    
    -- Fallback to simple parsing if YAML parser fails
    local package_data = {}
    
    local current_section = nil
    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1") -- trim
        
        if line:match("^[%w_]+:") then
            -- Section header
            current_section = line:match("^([%w_]+):")
            package_data[current_section] = package_data[current_section] or {}
        elseif line:match("^%s*-%s") and current_section then
            -- List item
            local item = line:match("^%s*-%s*(.+)")
            if item then
                if not package_data[current_section] then
                    package_data[current_section] = {}
                end
                if type(package_data[current_section]) == "table" then
                    table.insert(package_data[current_section], item)
                end
            end
        elseif line:match("^%s*[%w_]+:") and current_section then
            -- Key-value pair
            local key, value = line:match("^%s*([%w_]+):%s*(.+)")
            if key and value then
                value = value:gsub("^%s*(.-)%s*$", "%1") -- trim
                package_data[current_section] = package_data[current_section] or {}
                package_data[current_section][key] = value
            end
        end
    end
    
    return package_data
end

--- Convert mason-registry format to Freemason format
---@param package_name string
---@param package_data table
---@return table
local function convert_package_format(package_name, package_data)
    return {
        name = package_name,
        description = package_data.description,
        homepage = package_data.homepage,
        licenses = package_data.licenses,
        languages = package_data.languages,
        categories = package_data.categories,
        source = package_data.source,
        bin = package_data.bin,
        -- Add any additional Freemason-specific fields
        source_type = "mason-registry"
    }
end

--- Get package data for a tool
---@param package_name string
---@return table|nil
function M.get(package_name)
    -- Check cache first
    if package_cache[package_name] then
        return package_cache[package_name]
    end
    
    -- Load from mason-registry
    local package_data = load_package_data(package_name)
    if not package_data then
        return nil
    end
    
    -- Convert to Freemason format
    local converted = convert_package_format(package_name, package_data)
    
    -- Cache the result
    package_cache[package_name] = converted
    return converted
end

--- Get all available package names
---@return string[]
function M.get_all_package_names()
    if not registry_path then
        vim.notify("[Freemason] Mason-registry path not set", vim.log.levels.WARN)
        return {}
    end
    
    local packages = {}
    
    -- Try multiple possible directory structures
    local package_dirs = {
        registry_path,
        registry_path .. "/packages"
    }
    
    for _, packages_dir in ipairs(package_dirs) do
        -- Use vim.fn.readdir instead of io.popen for better compatibility
        local ok, entries = pcall(vim.fn.readdir, packages_dir)
        if ok and entries then
            for _, package in ipairs(entries) do
                -- Skip non-directories and hidden files
                if not package:match("^%.") then
                    -- Check if it's a directory and has package.yaml
                    local package_yaml = packages_dir .. "/" .. package .. "/package.yaml"
                    local file = io.open(package_yaml, "r")
                    if file then
                        file:close()
                        table.insert(packages, package)
                    end
                end
            end
        end
    end
    
    vim.notify(string.format("[Freemason] Found %d packages in %s", #packages, registry_path), vim.log.levels.INFO)
    return packages
end

--- Clear the package cache
function M.clear_cache()
    package_cache = {}
end

return M
