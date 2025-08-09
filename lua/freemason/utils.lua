local M = {}

-- Path utilities to replace plenary.path
M.Path = {}

function M.Path.new(path_str)
    local path = {}
    path._path = path_str or ""
    
    function path:absolute()
        if vim.fn.fnamemodify(self._path, ":p") == self._path then
            return self._path
        else
            return vim.fn.fnamemodify(self._path, ":p")
        end
    end
    
    function path:parent()
        local parent = vim.fn.fnamemodify(self._path, ":h")
        if parent == "." then
            return nil
        end
        return M.Path.new(parent)
    end
    
    function path:join(...)
        local parts = {...}
        local result = self._path or ""
        for _, part in ipairs(parts) do
            if part and result and result:sub(-1) == "/" then
                result = result .. part
            elseif part and result then
                result = result .. "/" .. part
            elseif part then
                result = part
            end
        end
        return M.Path.new(result)
    end
    
    function path:exists()
        return vim.fn.filereadable(self._path) == 1 or vim.fn.isdirectory(self._path) == 1
    end
    
    function path:is_file()
        return vim.fn.filereadable(self._path) == 1
    end
    
    function path:is_dir()
        return vim.fn.isdirectory(self._path) == 1
    end
    
    function path:read()
        if not self:is_file() then
            return nil
        end
        local file = io.open(self._path, "r")
        if not file then
            return nil
        end
        local content = file:read("*a")
        file:close()
        return content
    end
    
    function path:write(content)
        local file = io.open(self._path, "w")
        if not file then
            return false
        end
        file:write(content)
        file:close()
        return true
    end
    
    function path:mkdir(opts)
        opts = opts or {}
        local parents = opts.parents or false
        
        if parents then
            local parent = self:parent()
            if parent and not parent:exists() then
                parent:mkdir(opts)
            end
        end
        
        if not self:exists() then
            vim.fn.mkdir(self._path, "p")
        end
    end
    
    function path:rm(opts)
        opts = opts or {}
        local recursive = opts.recursive or false
        
        if recursive then
            vim.fn.delete(self._path, "rf")
        else
            vim.fn.delete(self._path)
        end
    end
    
    setmetatable(path, {
        __tostring = function(self)
            return self._path
        end,
        __concat = function(a, b)
            if type(a) == "string" then
                return M.Path.new(a .. tostring(b))
            else
                return M.Path.new(tostring(a) .. tostring(b))
            end
        end
    })
    
    return path
end

-- Job utilities to replace plenary.job
M.Job = {}

function M.Job.new(cmd, opts)
    opts = opts or {}
    local job = {}
    job.cmd = cmd
    job.opts = opts
    job.result = nil
    job.error = nil
    
    function job:start()
        local co = coroutine.running()
        if not co then
            error("Job:start() must be called from a coroutine")
        end
        
        local stdout = {}
        local stderr = {}
        
        local handle, pid = vim.uv.spawn(self.cmd[1], {
            args = vim.list_slice(self.cmd, 2),
            stdio = { nil, vim.uv.new_pipe(false), vim.uv.new_pipe(false) },
            cwd = self.opts.cwd,
            env = self.opts.env,
        }, function(code, signal)
            if code == 0 then
                self.result = table.concat(stdout, "")
            else
                self.error = table.concat(stderr, "")
            end
            coroutine.resume(co)
        end)
        
        if not handle then
            self.error = "Failed to start process"
            return
        end
        
        vim.uv.read_start(handle.stdout, function(err, data)
            if data then
                table.insert(stdout, data)
            end
        end)
        
        vim.uv.read_start(handle.stderr, function(err, data)
            if data then
                table.insert(stderr, data)
            end
        end)
        
        coroutine.yield()
        handle:close()
    end
    
    function job:sync()
        if coroutine.running() then
            self:start()
        else
            local co = coroutine.create(function()
                self:start()
            end)
            coroutine.resume(co)
        end
        return self.result, self.error
    end
    
    return job
end

-- YAML utilities (improved implementation)
M.yaml = {}

-- Try to use yq if available, otherwise use a more robust parser
function M.yaml.parse(content)
    -- First try using yq if available
    local temp_file = vim.fn.tempname() .. ".yaml"
    local file = io.open(temp_file, "w")
    if file then
        file:write(content)
        file:close()
        
        local yq_result = vim.fn.system("yq eval -o=json " .. vim.fn.shellescape(temp_file))
        os.remove(temp_file)
        
        if vim.v.shell_error == 0 and yq_result and #yq_result > 0 then
            local ok, parsed = pcall(vim.json.decode, yq_result)
            if ok and type(parsed) == "table" then
                return parsed
            end
        end
    end
    
    -- Fallback to improved parser
    return M.yaml._parse_improved(content)
end

-- Improved YAML parser that handles more complex structures
function M.yaml._parse_improved(content)
    local result = {}
    local lines = vim.split(content, "\n")
    local stack = {result}
    local indent_stack = {-1}
    
    for i, line in ipairs(lines) do
        local trimmed = vim.trim(line)
        if trimmed == "" or trimmed:match("^#") then
            goto continue
        end
        
        -- Calculate indentation
        local indent = 0
        for j = 1, #line do
            if line:sub(j, j) == " " then
                indent = indent + 1
            else
                break
            end
        end
        
        -- Pop stack until we find the right level
        while #indent_stack > 1 and indent <= indent_stack[#indent_stack] do
            table.remove(stack)
            table.remove(indent_stack)
        end
        
        -- Parse the line
        local key, value = line:match("^%s*([^:]+):%s*(.+)")
        if key then
            key = vim.trim(key)
            value = vim.trim(value)
            
            -- Handle different value types
            if value == "" then
                -- Empty value, might be a map or list
                stack[#stack][key] = {}
                table.insert(stack, stack[#stack][key])
                table.insert(indent_stack, indent)
            elseif value:match("^%[") then
                -- Array
                stack[#stack][key] = {}
                table.insert(stack, stack[#stack][key])
                table.insert(indent_stack, indent)
            elseif value:match("^%{") then
                -- Object
                stack[#stack][key] = {}
                table.insert(stack, stack[#stack][key])
                table.insert(indent_stack, indent)
            elseif value:match("^%-") then
                -- List item
                local item_value = vim.trim(value:sub(2))
                if not stack[#stack][key] then
                    stack[#stack][key] = {}
                end
                table.insert(stack[#stack][key], item_value)
            else
                -- Simple value
                -- Remove quotes if present
                if value:match('^".*"$') or value:match("^'.*'$") then
                    value = value:sub(2, -2)
                end
                stack[#stack][key] = value
            end
        elseif line:match("^%s*%-") then
            -- List item without key
            local item_value = vim.trim(line:match("^%s*%-%s*(.+)"))
            if item_value then
                -- Remove quotes if present
                if item_value:match('^".*"$') or item_value:match("^'.*'$") then
                    item_value = item_value:sub(2, -2)
                end
                table.insert(stack[#stack], item_value)
            end
        end
        
        ::continue::
    end
    
    return result
end

function M.yaml.encode(data)
    -- Simple YAML encoder for basic key-value pairs
    local lines = {}
    
    for key, value in pairs(data) do
        if type(value) == "string" then
            table.insert(lines, string.format('%s: "%s"', key, value))
        else
            table.insert(lines, string.format('%s: %s', key, tostring(value)))
        end
    end
    
    return table.concat(lines, "\n")
end

-- LSP utilities (to replace lspconfig.util)
M.lsp = {}

-- Root pattern function to replace lspconfig.util.root_pattern
function M.lsp.root_pattern(...)
  local patterns = {...}
  return function(startpath)
    local path = startpath
    while path ~= '/' and path ~= '' do
      for _, pattern in ipairs(patterns) do
        local found = vim.fn.glob(path .. '/' .. pattern, false, true)
        if #found > 0 then
          return path
        end
      end
      path = vim.fn.fnamemodify(path, ':h')
    end
    return startpath
  end
end

return M
