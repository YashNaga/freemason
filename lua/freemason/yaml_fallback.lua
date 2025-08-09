local M = {}

--- Extremely naive YAML parser for Mason-style package.yaml files
---@param input string
---@return table
function M.parse(input)
    local lines = vim.split(input, "\n")
    local result = {}
    local current_list = nil
    local current_key = nil

    for _, line in ipairs(lines) do
        local trimmed = vim.trim(line)

        -- Skip comments and empty lines
        if trimmed ~= "" and not trimmed:match("^#") then
            local key, value = trimmed:match("^(%S+):%s*(.*)$")
            if key then
                if value == "" then
                    -- List starting
                    current_list = {}
                    result[key] = current_list
                    current_key = key
                else
                    -- Scalar value
                    if value == "true" then
                        result[key] = true
                    elseif value == "false" then
                        result[key] = false
                    elseif tonumber(value) then
                        result[key] = tonumber(value)
                    else
                        result[key] = value
                    end
                    current_list = nil
                    current_key = nil
                end
            elseif trimmed:match("^%-") and current_list and current_key then
                local item = trimmed:match("^%-%s*(.+)$")
                table.insert(current_list, item)
            end
        end
    end

    return result
end

return M
