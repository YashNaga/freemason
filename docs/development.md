# Development Guide

## Overview

This guide is for developers who want to contribute to Freemason or understand its architecture.

## Architecture

Freemason uses a modular architecture with clear separation of concerns:

```
freemason/
├── init.lua                 # Main entry point
├── config.lua               # Configuration management
├── registry_cache.lua       # Cached registry access
├── registry_compiler.lua    # Registry compilation
├── ui.lua                   # User interface
├── commands.lua             # User commands
├── installer.lua            # Tool installation logic
├── launcher.lua             # LSP client management
├── lockfile.lua             # Installation tracking
├── adapters/                # External data adapters
│   ├── init.lua
│   ├── lazy.lua             # Lazy loading system
│   ├── lspconfig.lua        # nvim-lspconfig adapter
│   └── mason_registry.lua   # mason-registry adapter
├── external/                # External repositories
│   ├── nvim-lspconfig/      # LSP configurations
│   └── mason-registry/      # Tool definitions
├── lsp/                     # Local LSP configurations
│   └── configs/             # Custom LSP configs
└── registry/                # Local registry
    └── packages/            # Custom tool definitions
```

## Key Components

### Registry System

The registry system manages tool definitions and provides fast access:

- **`registry_cache.lua`**: Caches registry data for performance
- **`registry_compiler.lua`**: Pre-compiles registry into optimized structures
- **`adapters/`**: Converts external data formats to internal format

### Installation System

The installer handles tool downloads and setup:

- **`installer.lua`**: Main installation logic
- **`lockfile.lua`**: Tracks installed tools and versions
- **Multiple source support**: GitHub, NPM, Go, Cargo, etc.

### UI System

The UI provides user interaction:

- **`ui.lua`**: Floating window interface
- **`commands.lua`**: Command-line interface
- **Real-time updates**: Status checking and refresh

## Development Setup

### Prerequisites

- Neovim 0.8+
- Lua 5.1+
- Git
- Basic development tools

### Local Development

1. Clone the repository
2. Set up external repositories:
   ```bash
   git submodule add https://github.com/neovim/nvim-lspconfig external/nvim-lspconfig
   git submodule add https://github.com/williamboman/mason-registry external/mason-registry
   ```
3. Test your changes:
   ```lua
   -- In your init.lua
   require('freemason').setup()
   ```

### Testing

```lua
-- Test basic functionality
require('freemason').setup()
require('freemason.ui').open()

-- Test commands
vim.cmd('FreemasonInstall lua-language-server')
vim.cmd('FreemasonCache stats')
```

## Adding New Features

### Adding a New Tool Source

1. Add source type to `installer.lua`:
   ```lua
   local function install_from_new_source(tool_meta, callback)
       -- Implementation here
   end
   ```

2. Update source type detection:
   ```lua
   if source_id == "new_source" then
       install_from_new_source(tool_meta, callback)
   end
   ```

### Adding UI Features

1. Modify `ui.lua` for new UI elements
2. Add keymaps if needed
3. Update documentation

### Adding Commands

1. Add command to `commands.lua`
2. Update completion if needed
3. Add documentation

## Code Style

### Lua Conventions

- Use `local` for all variables
- Prefer `ipairs` for arrays, `pairs` for tables
- Use descriptive variable names
- Add comments for complex logic

### File Organization

- One module per file
- Clear separation of concerns
- Consistent naming conventions

### Error Handling

- Use `pcall` for external operations
- Provide meaningful error messages
- Log errors appropriately

## Performance Considerations

### Caching

- Cache expensive operations
- Use TTL for cache invalidation
- Clear cache when needed

### Lazy Loading

- Load external data on demand
- Use background processing for heavy operations
- Minimize startup time

### Memory Management

- Avoid memory leaks
- Clear unused data
- Monitor memory usage

## Debugging

### Enable Debug Logging

```lua
vim.lsp.set_log_level("debug")
```

### Debug Functions

```lua
-- Add to your development setup
local function debug_registry()
    local registry_cache = require('freemason.registry_cache')
    local stats = registry_cache.get_cache_stats()
    print(vim.inspect(stats))
end

local function debug_installation()
    local lockfile = require('freemason.lockfile')
    local installed = lockfile.get_all()
    print(vim.inspect(installed))
end
```

### Common Debug Scenarios

1. **Registry not loading**: Check adapter paths and permissions
2. **Installation failing**: Check network and dependencies
3. **UI not updating**: Check cache and refresh logic
4. **LSP not working**: Check registration and configuration

## Contributing

### Before Submitting

1. Test your changes thoroughly
2. Update documentation
3. Follow code style guidelines
4. Add tests if applicable

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with different configurations
5. Submit pull request with description

### Code Review

- Explain complex changes
- Provide context for decisions
- Address review comments
- Update documentation as needed

## Release Process

### Version Management

- Use semantic versioning
- Update version in appropriate files
- Create release notes

### Testing Checklist

- [ ] Basic installation works
- [ ] UI opens and functions
- [ ] Commands work correctly
- [ ] LSP integration works
- [ ] Performance is acceptable
- [ ] Documentation is up to date

### Distribution

- Tag releases in Git
- Update plugin managers
- Announce on relevant channels
