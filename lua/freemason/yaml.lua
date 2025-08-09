local utils = require("freemason.utils")
local Path = utils.Path

local M = {}

--- Parse YAML file
---@param file_path string|Path
---@return table|nil
function M.parse(file_path)
    local path = type(file_path) == "string" and Path.new(file_path) or file_path
    
    if not path:exists() then
        return nil
    end
    
    local content = path:read()
    if not content then
        return nil
    end
    
    return utils.yaml.parse(content)
end

--- Encode table to YAML
---@param data table
---@return string
function M.encode(data)
    return utils.yaml.encode(data)
end

return M