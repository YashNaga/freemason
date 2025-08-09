local M = {}

-- Use lazy adapter system
local lazy_adapters = require("freemason.adapters.lazy")

-- Expose lazy adapter functions
M.lspconfig = lazy_adapters.get_lspconfig
M.mason_registry = lazy_adapters.get_mason_registry

-- Expose initialization functions
M.initialize_adapters_async = lazy_adapters.initialize_adapters_async
M.initialize_adapters_sync = lazy_adapters.initialize_adapters_sync
M.is_initialized = lazy_adapters.is_initialized
M.is_initializing = lazy_adapters.is_initializing

-- Expose path setting functions
M.set_lspconfig_path = lazy_adapters.set_lspconfig_path
M.set_mason_registry_path = lazy_adapters.set_mason_registry_path

return M
