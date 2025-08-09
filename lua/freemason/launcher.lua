local M = {}

-- Track registered LSPs and their clients
local registered_lsps = {}
local active_clients = {}
local idle_timers = {}

-- Expose registered_lsps for debugging
M.registered_lsps = registered_lsps

local function deep_merge(tbl1, tbl2)
  for k, v in pairs(tbl2) do
    if type(v) == "table" and type(tbl1[k]) == "table" then
      deep_merge(tbl1[k], v)
    else
      tbl1[k] = v
    end
  end
  return tbl1
end

--- Get LSP configuration from adapters or fallback
---@param tool_name string
---@return table|nil
local function get_lsp_config(tool_name)
    local config = require("freemason.config").get()
    
    -- Try adapter first (lazy loaded)
    local adapters = require("freemason.adapters")
    local adapter = adapters.lspconfig()
    if adapter then
        local adapter_config = adapter.get(tool_name)
        if adapter_config and adapter_config.config then
            return adapter_config.config
        end
    end
    
    -- Fallback to local config
    local ok, default_config = pcall(require, "freemason.lsp.configs." .. tool_name)
    if ok and type(default_config) == "table" then
        return default_config
    end
    
    if config.lsp.debug then
        vim.notify("[Freemason] No config found for: " .. tool_name, vim.log.levels.WARN)
    end
    return nil
end

--- Register an LSP configuration (doesn't start it)
---@param tool_name string
M.register_lsp = function(tool_name)
  local config = require("freemason.config").get()
  local user_handlers = config.overrides or {}

  local default_config = get_lsp_config(tool_name)
  if not default_config then
    return false
  end

  local final_config = vim.deepcopy(default_config)

  local override = user_handlers[tool_name]
  if override then
    deep_merge(final_config, override)
  end

  if not final_config.cmd then
    if config.lsp.debug then
      vim.notify("[Freemason] No `cmd` defined in config for: " .. tool_name, vim.log.levels.WARN)
    end
    return false
  end

  -- Register with Neovim's built-in LSP registry and remember locally
  local ok, result = pcall(vim.lsp.config, tool_name, final_config)
  if not ok then
    if config.lsp.debug then
      vim.notify("[Freemason] Failed to register LSP " .. tool_name .. ": " .. tostring(result), vim.log.levels.ERROR)
    end
    return false
  end
  registered_lsps[tool_name] = final_config
  return true
end

--- Unregister an LSP configuration
---@param tool_name string
M.unregister_lsp = function(tool_name)
  -- Remove from Neovim's LSP registry
  pcall(vim.lsp.config, tool_name, nil)
  -- Remove from our local registry
  registered_lsps[tool_name] = nil
  return true
end

--- Get all registered LSPs
---@return table
M.get_registered_lsps = function()
  return registered_lsps
end

--- Enable an LSP for the current buffer using built-in API
---@param tool_name string
M.enable_lsp = function(tool_name)
  -- Check if LSP is already active for this buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local attached_clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(attached_clients) do
    if client.name == tool_name then
      -- LSP is already attached to this buffer
      return true
    end
  end
  
  -- Check if LSP client is already running
  local active_clients = vim.lsp.get_clients()
  for _, client in ipairs(active_clients) do
    if client.name == tool_name then
      -- LSP client is already running, just attach it to the buffer
      local ok, result = pcall(vim.lsp.buf_attach_client, bufnr, client.id)
      if ok then
        return true
      else
        return false
      end
    end
  end
  
  -- Ensure it's registered
  if not registered_lsps[tool_name] then
    if not M.register_lsp(tool_name) then
      return false
    end
  end
  
  -- Get the current buffer
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  
  -- Check if the LSP supports this filetype
  local config = registered_lsps[tool_name]
  if not config or not config.filetypes then
    return false
  end
  
  local supports_filetype = false
  -- Handle both string and table filetypes
  if type(config.filetypes) == "string" then
    supports_filetype = config.filetypes == filetype
  elseif type(config.filetypes) == "table" then
    for _, ft in ipairs(config.filetypes) do
      if ft == filetype then
        supports_filetype = true
        break
      end
    end
  end
  
  if not supports_filetype then
    return false
  end
  
  -- Try to start the client manually since vim.lsp.enable() seems unreliable
  local success, client_id = pcall(function()
    return vim.lsp.start_client({
      name = tool_name,
      cmd = config.cmd,
      root_dir = config.root_dir or vim.fn.getcwd(),
      filetypes = config.filetypes,
      settings = config.settings,
      cwd = config.cwd,
      cmd_env = config.cmd_env,
      root_markers = config.root_markers,
      init_options = config.init_options,
      capabilities = config.capabilities,
      handlers = config.handlers,
      on_attach = config.on_attach,
      on_init = config.on_init,
      before_init = config.before_init,
      on_exit = config.on_exit,
      flags = config.flags,
      offset_encoding = config.offset_encoding,
      reuse_client = config.reuse_client,
      workspace_required = config.workspace_required,
      get_language_id = config.get_language_id,
      message_level = config.message_level,
      name = config.name or tool_name
    })
  end)
  
  if not success then
    vim.notify("[Freemason] Failed to start LSP client " .. tool_name .. ": " .. tostring(client_id), vim.log.levels.ERROR)
    return false
  end
  
  if client_id then
    -- Attach the client to the current buffer
    local ok, result = pcall(vim.lsp.buf_attach_client, bufnr, client_id)
    if ok then
      -- Track the client
      active_clients[client_id] = {
        name = tool_name,
        buffer = bufnr,
        last_activity = vim.loop.now()
      }
      return true
    else
      -- If attachment failed, stop the client
      pcall(vim.lsp.stop_client, client_id)
      return false
    end
  else
    -- Fallback to vim.lsp.enable() if manual start fails
    pcall(vim.lsp.enable, tool_name)
    return true
  end
end

--- Stop an LSP client
---@param client_id number
M.stop_lsp_client = function(client_id)
  local client_info = active_clients[client_id]
  if not client_info then
    return
  end
  local client = vim.lsp.get_client_by_id(client_id)
  if client and client.stop then
    client.stop()
  end
  if idle_timers[client_id] then
    idle_timers[client_id]:stop()
    idle_timers[client_id] = nil
  end
  active_clients[client_id] = nil
end

--- Update LSP client last activity timestamp
---@param client_id number
M.update_client_activity = function(client_id)
  if not active_clients[client_id] then
    active_clients[client_id] = { last_activity = 0 }
  end
  active_clients[client_id].last_activity = vim.loop.now()
end

local function should_exclude_buffer(_)
  -- placeholder for user exclusions if needed later
  return false
end

--- Start idle shutdown timer for a client
---@param client_id number
local function start_idle_timer(client_id)
  local config = require("freemason.config").get()
  local lsp_config = config.lsp.idle_shutdown

  if not lsp_config.enabled then
    return
  end

  if not active_clients[client_id] then
    return
  end

  if idle_timers[client_id] then
    idle_timers[client_id]:stop()
  end

  idle_timers[client_id] = vim.defer_fn(function()
    local current = active_clients[client_id]
    if not current then
      return
    end
    local since = vim.loop.now() - (current.last_activity or 0)
    if since >= lsp_config.timeout then
      -- Stop the client if no excluded buffers are attached
      local client = vim.lsp.get_client_by_id(client_id)
      if not client then
        return
      end
      local attached = client.attached_buffers or {}
      local has_excluded = false
      for bufnr, _ in pairs(attached) do
        if should_exclude_buffer(bufnr) then
          has_excluded = true
          break
        end
      end
      if not has_excluded then
        M.stop_lsp_client(client_id)
      end
    else
      -- Reschedule
      start_idle_timer(client_id)
    end
  end, lsp_config.check_interval)
end

--- Setup idle shutdown monitoring
M.setup_idle_shutdown = function()
  local config = require("freemason.config").get()
  local lsp_config = config.lsp.idle_shutdown
  if not lsp_config.enabled then
    return
  end

  -- Mark activity on cursor movement for all clients attached to current buffer
  vim.api.nvim_create_autocmd("CursorMoved", {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(clients) do
        M.update_client_activity(client.id)
        start_idle_timer(client.id)
      end
    end,
  })

  -- Mark activity on LSP progress events
  vim.api.nvim_create_autocmd("LspProgress", {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(clients) do
        M.update_client_activity(client.id)
        start_idle_timer(client.id)
      end
    end,
  })

  -- Track new attachments
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if client_id then
        M.update_client_activity(client_id)
        start_idle_timer(client_id)
      end
    end,
  })

  -- Clean up on detach
  vim.api.nvim_create_autocmd("LspDetach", {
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if client_id then
        M.stop_lsp_client(client_id)
      end
    end,
  })
end

--- Legacy function for backward compatibility
---@param tool_name string
M.setup_lsp = function(tool_name)
  return M.register_lsp(tool_name)
end

--- Get list of registered LSPs
---@return table
M.get_registered_lsps = function()
  return registered_lsps
end

return M
