# Troubleshooting Guide

## Common Issues

### UI Performance

**Problem**: UI is slow to open for the first time
- **Cause**: Registry compilation on first access
- **Solution**: This is normal behavior. Subsequent opens are instant
- **Workaround**: None needed - one-time cost

**Problem**: UI feels laggy or unresponsive
- **Cause**: Large number of tools or slow status checking
- **Solution**: 
  - Clear cache: `:FreemasonCache clear`
  - Check system resources
  - Reduce cache TTL in configuration

### Installation Issues

**Problem**: Tool installation fails with "No source information"
- **Cause**: Tool not found in registry or missing source data
- **Solution**: 
  - Check if tool name is correct
  - Verify registry is properly initialized
  - Try refreshing: `:FreemasonCache clear`

**Problem**: Installation fails with network error
- **Cause**: Internet connectivity or firewall issues
- **Solution**:
  - Check internet connection
  - Verify firewall settings
  - Try different network if available

**Problem**: Permission denied during installation
- **Cause**: Insufficient permissions for installation directory
- **Solution**:
  - Check directory permissions
  - Run Neovim with appropriate permissions
  - Change installation directory in config

### LSP Issues

**Problem**: LSP not working after installation
- **Cause**: LSP not properly registered or configured
- **Solution**:
  - Restart Neovim
  - Check LSP status: `:LspInfo`
  - Manually start LSP: `:LspStart <server_name>`

**Problem**: LSP client quits unexpectedly
- **Cause**: Configuration issues or missing dependencies
- **Solution**:
  - Check LSP logs: `:LspLog`
  - Verify tool installation
  - Reinstall the LSP server

**Problem**: Multiple LSP clients for same filetype
- **Cause**: Conflicting LSP configurations
- **Solution**:
  - Check existing LSP configurations
  - Disable conflicting LSPs
  - Use LSP-specific configuration

### Cache Issues

**Problem**: Tool status not updating
- **Cause**: Stale cache data
- **Solution**: `:FreemasonCache clear`

**Problem**: Cache stats showing incorrect data
- **Cause**: Cache corruption or sync issues
- **Solution**: `:FreemasonCache clear`

### Registry Issues

**Problem**: "Registry not compiled" errors
- **Cause**: Registry compilation failed
- **Solution**:
  - Check external repository paths
  - Verify repository access
  - Clear cache and retry

**Problem**: Missing tools in UI
- **Cause**: Registry not properly loaded
- **Solution**:
  - Check adapter initialization
  - Verify external repository paths
  - Refresh UI: `r` key in UI

## Debug Mode

Enable debug logging for detailed troubleshooting:

```lua
-- Enable LSP debug logging
vim.lsp.set_log_level("debug")

-- Enable Neovim debug logging
vim.lsp.set_log_level("trace")
```

### Debug Commands

```vim
" Check LSP status
:LspInfo

" View LSP logs
:LspLog

" Check Neovim health
:checkhealth

" Check specific plugin health
:checkhealth freemason
```

## Performance Optimization

### Reduce Cache TTL

For faster status updates:

```lua
require('freemason').setup({
  cache = {
    ttl = 60  -- 1 minute
  }
})
```

### Increase Cache TTL

For better performance:

```lua
require('freemason').setup({
  cache = {
    ttl = 1800  -- 30 minutes
  }
})
```

### Disable Background Status Checking

If UI is too resource-intensive:

```lua
-- This would require code modification
-- Currently not configurable
```

## System Requirements

### Required Dependencies

- **curl**: For downloading tools
- **tar**: For extracting archives
- **unzip**: For extracting ZIP files
- **gunzip**: For extracting gzipped files
- **chmod**: For setting executable permissions

### Optional Dependencies

- **git**: For Git-based installations
- **npm**: For Node.js packages
- **go**: For Go modules
- **cargo**: For Rust packages
- **pip**: For Python packages

### Check Dependencies

```bash
# Check if required tools are available
which curl tar unzip gunzip chmod

# Check optional tools
which git npm go cargo pip
```

## Platform-Specific Issues

### macOS

**Problem**: Permission issues with symlinks
- **Solution**: Grant Full Disk Access to Terminal/Neovim

**Problem**: Homebrew conflicts
- **Solution**: Use system tools or adjust PATH

### Linux

**Problem**: SELinux blocking operations
- **Solution**: Configure SELinux policies or disable temporarily

**Problem**: AppArmor restrictions
- **Solution**: Configure AppArmor profiles

### Windows

**Problem**: Path length limitations
- **Solution**: Use shorter installation paths

**Problem**: Symlink permissions
- **Solution**: Run as Administrator or enable Developer Mode

## Getting Help

### Before Asking for Help

1. Check this troubleshooting guide
2. Enable debug logging
3. Try clearing cache: `:FreemasonCache clear`
4. Restart Neovim
5. Check system dependencies

### Useful Information to Include

When reporting issues, include:

- Neovim version: `nvim --version`
- Operating system and version
- Freemason configuration
- Error messages and logs
- Steps to reproduce
- Expected vs actual behavior

### Debug Information

Collect debug information:

```lua
-- Add to your init.lua for debugging
vim.api.nvim_create_user_command("FreemasonDebug", function()
  local config = require('freemason.config')
  local registry_cache = require('freemason.registry_cache')
  
  print("=== Freemason Debug Info ===")
  print("Config:", vim.inspect(config.get()))
  print("Registry compiled:", registry_cache.get_cache_stats().compiled)
  print("Status cache size:", registry_cache.get_cache_stats().status_cache_size)
end, {})
```

Then run: `:FreemasonDebug`
