local config = require("freemason.config")
local utils = require("freemason.utils")
local Path = utils.Path

local M = {}

--- Get the lockfile path
---@return Path
local function get_lockfile_path()
    local cfg = config.get()
    local lockfile_name = cfg.install.lockfile
    local data_dir = vim.fn.stdpath("data") .. "/freemason"
    return Path.new(data_dir):join(lockfile_name)
end

--- Load lockfile data
---@return table
function M.load()
    local lockfile_path = get_lockfile_path()
    
    if not lockfile_path:exists() then
        return {}
    end
    
    local content = lockfile_path:read()
    if not content then
        return {}
    end
    
    local ok, data = pcall(vim.json.decode, content)
    if not ok or type(data) ~= "table" then
        return {}
    end
    
    return data
end

--- Save lockfile data
---@param data table
function M.save(data)
    local lockfile_path = get_lockfile_path()
    local content = vim.json.encode(data)
    
    -- Ensure directory exists
    local parent = lockfile_path:parent()
    if parent then
        parent:mkdir({ parents = true })
    end
    
    lockfile_path:write(content)
end

--- Get status of a tool
---@param name string
---@return table|nil
function M.get_status(name)
    local lockfile_data = M.load()
    return lockfile_data[name]
end

--- Set status of a tool
---@param name string
---@param status table
function M.set_status(name, status)
    local lockfile_data = M.load()
    lockfile_data[name] = status
    M.save(lockfile_data)
end

--- Remove status of a tool
---@param name string
function M.remove_status(name)
    local lockfile_data = M.load()
    lockfile_data[name] = nil
    M.save(lockfile_data)
end

--- Check if a tool is listed in the lockfile
---@param name string
---@return boolean
function M.is_listed(name)
    local status = M.get_status(name)
    return status ~= nil
end

--- Add a tool to the lockfile
---@param tool_data table
function M.add(tool_data)
    M.set_status(tool_data.name, tool_data)
end

--- Remove a tool from the lockfile
---@param name string
function M.remove(name)
    M.remove_status(name)
end

return M
