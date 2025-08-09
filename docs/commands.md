# Commands Reference

## Overview

Freemason provides several user commands for managing tools and interacting with the plugin.

## Core Commands

### `Freemason`

Opens the Freemason UI interface.

**Usage:**
```vim
:Freemason
```

**Description:**
Opens a floating window with a categorized list of all available tools. You can browse, install, update, and manage tools through this interface.

### `FreemasonInstall`

Installs a specific tool.

**Usage:**
```vim
:FreemasonInstall <tool_name>
```

**Examples:**
```vim
:FreemasonInstall lua-language-server
:FreemasonInstall clangd
:FreemasonInstall black
```

**Description:**
Downloads and installs the specified tool. The tool will be available for use immediately after installation.

### `FreemasonUpdate`

Updates a specific tool.

**Usage:**
```vim
:FreemasonUpdate <tool_name>
```

**Examples:**
```vim
:FreemasonUpdate lua-language-server
:FreemasonUpdate all
```

**Description:**
Checks for updates and installs the latest version of the specified tool. Use `all` to update all installed tools with available updates.

### `FreemasonUninstall`

Uninstalls a specific tool.

**Usage:**
```vim
:FreemasonUninstall <tool_name>
```

**Examples:**
```vim
:FreemasonUninstall lua-language-server
:FreemasonUninstall clangd
```

**Description:**
Removes the specified tool and cleans up associated files. The tool will no longer be available.

### `FreemasonCache`

Manages the Freemason cache.

**Usage:**
```vim
:FreemasonCache [clear|stats]
```

**Examples:**
```vim
:FreemasonCache clear
:FreemasonCache stats
```

**Description:**
- `clear`: Clears all cached data (status cache, registry cache)
- `stats`: Shows cache statistics (number of cached items, registry status)

## Command Completion

All commands that accept tool names support tab completion:

```vim
:FreemasonInstall <Tab>  " Shows list of available tools
:FreemasonUpdate <Tab>   " Shows list of available tools
:FreemasonUninstall <Tab> " Shows list of available tools
```

## UI Keymaps

When the Freemason UI is open, the following keymaps are available:

| Key | Action | Description |
|-----|--------|-------------|
| `i` | Install | Install the tool under cursor |
| `u` | Update/Uninstall | Update if installed, uninstall if not |
| `U` | Update All | Update all tools with available updates |
| `r` | Refresh | Refresh the UI and tool statuses |
| `c` | Change Category | Cycle through tool categories |
| `<CR>` | Toggle Details | Show/hide tool details |
| `q` | Quit | Close the UI |

## Examples

### Basic Workflow

```vim
" Open UI to browse tools
:Freemason

" Install a specific tool
:FreemasonInstall lua-language-server

" Check for updates
:FreemasonUpdate lua-language-server

" Uninstall if needed
:FreemasonUninstall lua-language-server
```

### Batch Operations

```vim
" Update all tools
:FreemasonUpdate all

" Clear cache to force refresh
:FreemasonCache clear

" Check cache status
:FreemasonCache stats
```

### Troubleshooting

```vim
" Clear cache if having issues
:FreemasonCache clear

" Reinstall a problematic tool
:FreemasonUninstall <tool>
:FreemasonInstall <tool>
```

## Error Handling

Commands will show appropriate error messages for:

- Invalid tool names
- Network connectivity issues
- Permission problems
- Missing dependencies
- Installation failures

## Integration with LSP

After installing LSP servers, they are automatically registered and can be used with Neovim's built-in LSP client:

```vim
" Install an LSP server
:FreemasonInstall rust_analyzer

" The LSP will be automatically available for Rust files
" No additional configuration needed
```

## Performance Notes

- Commands are designed to be non-blocking
- Installation progress is shown in the UI
- Cache operations are fast and don't block Neovim
- Tool status is cached for better performance
