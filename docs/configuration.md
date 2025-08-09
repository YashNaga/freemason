# Configuration Guide

## Overview

Freemason is designed to work out of the box with sensible defaults, but offers extensive configuration options for advanced users.

## Basic Configuration

```lua
require('freemason').setup({
  -- Your configuration here
})
```

## Configuration Options

### `install_root_dir`

**Type**: `string`  
**Default**: `vim.fn.stdpath("data") .. "/freemason"`

The directory where tools will be installed.

```lua
require('freemason').setup({
  install_root_dir = "~/.local/share/freemason"
})
```

### `registry`

**Type**: `table`

Configuration for external registry sources.

#### `registry.lspconfig_path`

**Type**: `string`  
**Default**: `nil`

Path to nvim-lspconfig repository for LSP configurations.

```lua
require('freemason').setup({
  registry = {
    lspconfig_path = "~/repos/nvim-lspconfig"
  }
})
```

#### `registry.mason_registry_path`

**Type**: `string`  
**Default**: `nil`

Path to mason-registry repository for tool definitions.

```lua
require('freemason').setup({
  registry = {
    mason_registry_path = "~/repos/mason-registry"
  }
})
```

### `ui`

**Type**: `table`

UI-specific configuration options.

#### `ui.width`

**Type**: `number`  
**Default**: `0.8`

Width of the UI window as a percentage of screen width.

#### `ui.height`

**Type**: `number`  
**Default**: `0.8`

Height of the UI window as a percentage of screen height.

#### `ui.border`

**Type**: `string`  
**Default**: `"rounded"`

Border style for the UI window. Options: `"none"`, `"single"`, `"double"`, `"rounded"`, `"solid"`, `"shadow"`.

### `cache`

**Type**: `table`

Cache configuration options.

#### `cache.ttl`

**Type**: `number`  
**Default**: `600`

Time-to-live for status cache in seconds.

## Complete Example

```lua
require('freemason').setup({
  -- Installation directory
  install_root_dir = vim.fn.stdpath("data") .. "/freemason",
  
  -- External registry sources
  registry = {
    lspconfig_path = "~/repos/nvim-lspconfig",
    mason_registry_path = "~/repos/mason-registry"
  },
  
  -- UI configuration
  ui = {
    width = 0.9,
    height = 0.8,
    border = "rounded"
  },
  
  -- Cache configuration
  cache = {
    ttl = 300  -- 5 minutes
  }
})
```

## Environment Variables

Freemason respects the following environment variables:

- `FREEMASON_INSTALL_DIR`: Override installation directory
- `FREEMASON_CACHE_TTL`: Override cache TTL (in seconds)

## Performance Tuning

### Reduce Cache TTL

For faster status updates but more frequent checks:

```lua
require('freemason').setup({
  cache = {
    ttl = 60  -- 1 minute
  }
})
```

### Increase Cache TTL

For better performance but slower status updates:

```lua
require('freemason').setup({
  cache = {
    ttl = 1800  -- 30 minutes
  }
})
```

## Troubleshooting

### Debug Configuration

Enable debug logging to see configuration loading:

```lua
vim.lsp.set_log_level("debug")
require('freemason').setup({
  -- Your config here
})
```

### Validate Configuration

Check if your configuration is valid:

```lua
local config = require('freemason.config')
print(vim.inspect(config.get()))
```
