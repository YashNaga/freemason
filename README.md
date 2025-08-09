# Freemason

> **⚠️ Early Development Notice**  
> This plugin is in early development and not thoroughly tested. Due to lack of optimisation the plugin is kind of slow. Breaking changes are likely to occur. Pull requests, bug reports, and community support is very welcome. I'm broke, jobless and have school so frequency in changes may fluctuate

A "fast", lightweight Neovim plugin for managing LSP servers, formatters, linters, and other development tools.

## Features

- 🚀 **Fast startup** - Lazy registry compilation for instant Neovim startup
- 🛠️ **Tool management** - Install, update, and uninstall development tools
- 📦 **Multiple sources** - Support for GitHub releases, NPM, Go, Cargo, PyPI, and more
- 🎯 **Smart caching** - Efficient caching system for optimal performance
- 🔧 **LSP integration** - Automatic LSP registration and management
- 🎨 **Clean UI** - Simple, categorized interface for tool management

## Dependencies

Freemason requires the following system dependencies for tool installation:

- **curl** - For downloading files from GitHub releases and other sources
- **tar** - For extracting compressed archives
- **unzip** - For extracting ZIP files
- **git** - For cloning repositories (optional, for some tools)

Most systems have these installed by default. On macOS, you can install them with:
```bash
brew install curl tar unzip git
```

On Ubuntu/Debian:
```bash
sudo apt install curl tar unzip git
```

## Installation

```lua
-- Packer
use 'YashNaga/freemason'

-- Lazy.nvim
{
  'YashNaga/freemason',
  config = function()
    require('freemason').setup()
  end
}

-- vim-plug
Plug 'YashNaga/freemason'
```

### Manual installation

```bash
# For full functionality (recommended)
git clone --recursive https://github.com/YashNaga/freemason ~/.config/nvim/lua/freemason

# For basic functionality only
git clone https://github.com/YashNaga/freemason ~/.config/nvim/lua/freemason
```

**Note**: The `--recursive` flag includes external repositories (nvim-lspconfig and mason-registry) for full functionality. Without it, you'll still have basic functionality, and Freemason will attempt to auto-detect external repositories if they're available elsewhere.

## Setup

### Basic Setup (Works Out-of-the-Box)

```lua
require('freemason').setup()
```

Freemason works immediately with smart defaults! The plugin automatically detects and uses external repositories when available, giving you access to 500+ tools without any configuration.

### Full Functionality (Automatic Path Detection)

Freemason automatically detects and uses external repositories for full functionality:

#### Option 1: Using Git Submodules (Recommended)

```bash
# Clone Freemason with submodules
git clone --recursive https://github.com/your-username/freemason ~/.config/nvim/lua/freemason

# Or if you already cloned it, add submodules
cd ~/.config/nvim/lua/freemason
git submodule add https://github.com/neovim/nvim-lspconfig external/nvim-lspconfig
git submodule add https://github.com/williamboman/mason-registry external/mason-registry
git submodule update --init --recursive
```

Then use the default configuration:

```lua
require('freemason').setup()
-- Freemason automatically detects and uses:
-- ./external/nvim-lspconfig/lsp
-- ./external/mason-registry/packages
```

#### Option 2: Manual Setup

If you prefer to place the repositories elsewhere:

```bash
# Clone external repositories to custom locations
git clone https://github.com/neovim/nvim-lspconfig /path/to/nvim-lspconfig
git clone https://github.com/williamboman/mason-registry /path/to/mason-registry
```

Then configure Freemason to use them:

```lua
require('freemason').setup({
  registry = {
    lspconfig_path = "/path/to/nvim-lspconfig/lsp",
    mason_registry_path = "/path/to/mason-registry/packages"
  }
})
```

#### Option 3: Plugin Manager Installation

When installed via plugin managers (Packer, Lazy.nvim, vim-plug), Freemason automatically detects the correct paths:

```lua
-- Works automatically with any plugin manager
require('freemason').setup()
```

**Note**: Freemason works immediately with basic functionality. When external repositories are available, you get access to 500+ additional tools automatically. You'll see a notification about the current status on startup.

### Automatic Path Detection

Freemason automatically detects external repositories in the following order:

1. **User Configuration** - Paths specified in your config
2. **Relative Paths** - `./external/nvim-lspconfig/lsp` and `./external/mason-registry/packages`
3. **Absolute Paths** - Automatically calculated based on plugin location (for plugin manager installations)

This ensures Freemason works correctly whether you:
- Clone the repository manually
- Install via plugin managers
- Use custom repository locations

## Configuration

### Basic Configuration

```lua
require('freemason').setup({
  -- Your configuration here
})
```

### Advanced Configuration

```lua
require('freemason').setup({
  -- UI configuration
  ui = {
    auto_open = false,           -- Open UI at startup
    border = "rounded",          -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
    show_status_icons = true,    -- Show ✓ ✗ ? icons
    show_versions = true,        -- Show version information
    show_filter = true,          -- Show category filters
    width = 0.6,                 -- UI width (percentage of screen)
    height = 0.7,                -- UI height (percentage of screen)
    icons = {
      installed = "✓",           -- Icon for installed tools
      not_installed = "✗",       -- Icon for not installed tools
      pending = "…"              -- Icon for pending installation
    }
  },

  -- Installation configuration
  install = {
    root_dir = vim.fn.stdpath("data") .. "/freemason/packages",  -- Installation directory
    auto_update = false,         -- Auto-update tools at startup
    lockfile = "freemason-lock.json",  -- Lockfile path
    symlink_bins = true,         -- Create symlinks to central bin directory
    bin_dir = vim.fn.stdpath("data") .. "/freemason/bin"  -- Binary symlink directory
  },

  -- LSP configuration
  lsp = {
    -- Idle shutdown (like garbage-day.nvim)
    idle_shutdown = {
      enabled = true,            -- Enable idle shutdown
      timeout = 300000,          -- Shutdown after 5 minutes (in ms)
      check_interval = 60000,    -- Check every minute (in ms)
      exclude_filetypes = {},    -- Filetypes to exclude from shutdown
      exclude_buftypes = {       -- Buftypes to exclude from shutdown
        "nofile", "prompt", "quickfix", "help", "terminal"
      }
    },

    -- LSP keymaps
    keymaps = {
      enabled = true,            -- Enable/disable LSP keymaps
      defaults = {
        -- Navigation
        ["gd"] = { "vim.lsp.buf.definition", "Go to definition" },
        ["gD"] = { "vim.lsp.buf.declaration", "Go to declaration" },
        ["gr"] = { "vim.lsp.buf.references", "Go to references" },
        ["gi"] = { "vim.lsp.buf.implementation", "Go to implementation" },
        ["gt"] = { "vim.lsp.buf.type_definition", "Go to type definition" },
        
        -- Information
        ["K"] = { "vim.lsp.buf.hover", "Hover documentation" },
        ["<leader>k"] = { "vim.lsp.buf.signature_help", "Signature help" },
        
        -- Actions
        ["<leader>rn"] = { "vim.lsp.buf.rename", "Rename symbol" },
        ["<leader>ca"] = { "vim.lsp.buf.code_action", "Code action" },
        ["<leader>f"] = { "vim.lsp.buf.format", "Format document" },
        
        -- Diagnostics
        ["<leader>d["] = { "vim.diagnostic.goto_prev", "Previous diagnostic" },
        ["<leader>d]"] = { "vim.diagnostic.goto_next", "Next diagnostic" },
        ["<leader>dl"] = { "vim.diagnostic.setloclist", "Show diagnostics" },
        ["<leader>do"] = { "vim.diagnostic.open_float", "Show diagnostic" }
      }
    },

    -- Diagnostic configuration
    diagnostics = {
      enabled = true,            -- Enable/disable diagnostics
      signs = {
        enabled = true,          -- Enable diagnostic signs in gutter
        text = {                 -- Nerd font icons
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 '
        },
        text_fallback = {        -- Fallback text
          [vim.diagnostic.severity.ERROR] = 'E',
          [vim.diagnostic.severity.WARN] = 'W',
          [vim.diagnostic.severity.INFO] = 'I',
          [vim.diagnostic.severity.HINT] = 'H'
        }
      },
      virtual_text = {
        enabled = true,          -- Enable inline diagnostic messages
        source = 'if_many',      -- Show source if multiple diagnostics
        spacing = 2              -- Spacing between text and code
      },
      underline = {
        enabled = true,          -- Enable underlines
        severity = vim.diagnostic.severity.ERROR  -- Only underline errors
      },
      float = {
        enabled = true,          -- Enable diagnostic popups
        border = 'rounded',      -- Border style
        source = 'if_many'       -- Show source if multiple diagnostics
      },
      severity_sort = true       -- Sort diagnostics by severity
    },

    debug = false                -- Enable debug output
  },

  -- External repository configuration (optional - auto-detected by default)
  registry = {
    lspconfig_path = "./external/nvim-lspconfig/lsp",        -- Path to nvim-lspconfig LSP configs
    mason_registry_path = "./external/mason-registry/packages" -- Path to mason-registry packages
  },

  -- Hooks
  hooks = {
    enable = true               -- Enable FreemasonSetupHook autocmd
  },

  -- Tool-specific overrides
  overrides = {
    -- Example: Override lua-language-server settings
    -- lua_ls = {
    --   settings = {
    --     Lua = {
    --       runtime = { version = "LuaJIT" },
    --       diagnostics = { globals = { "vim" } }
    --   }
    -- }
  }
})
```

## Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `Freemason` | Open the Freemason UI |
| `FreemasonInstall <tool>` | Install a specific tool |
| `FreemasonUpdate <tool>` | Update a specific tool |
| `FreemasonUninstall <tool>` | Uninstall a specific tool |
| `FreemasonCache [clear\|stats]` | Manage cache (clear or show stats) |

### Examples

```vim
" Install lua-language-server
:FreemasonInstall lua-language-server

" Update all tools with available updates
:FreemasonUpdate all

" Clear cache
:FreemasonCache clear

" Show cache statistics
:FreemasonCache stats
```

## UI Usage

### Opening the UI

```vim
:Freemason
```

### Keymaps

| Key | Action |
|-----|--------|
| `i` | Install selected tool |
| `u` | Update/uninstall selected tool |
| `U` | Update all tools with available updates |
| `r` | Refresh the UI |
| `c` | Change category filter |
| `<CR>` | Toggle tool details |
| `q` | Close UI |

### Categories

Tools are organized into categories:
- **All** - Show all tools
- **LSP** - Language Server Protocol servers
- **Formatter** - Code formatters
- **Linter** - Code linters
- **DAP** - Debug Adapter Protocol

### Tool Details

Press `<CR>` on any tool to see:
- Description
- Installed version
- Homepage/GitHub link
- Supported languages
- Category
- Executables

## Supported Tools

Freemason supports installation from various sources:

- **GitHub Releases** - Direct downloads from GitHub
- **NPM** - Node.js packages
- **Go** - Go modules
- **Cargo** - Rust packages
- **PyPI** - Python packages
- **Gem** - Ruby gems
- **Composer** - PHP packages
- **NuGet** - .NET packages
- **LuaRocks** - Lua packages

## LSP Integration

Freemason provides built-in LSP integration that's different from nvim-lspconfig:

### How It Works

1. **Automatic Registration**: When you install an LSP server, it's automatically registered with Neovim's built-in LSP system
2. **No External Dependencies**: Unlike nvim-lspconfig, you don't need to manually configure each LSP
3. **Built-in Keymaps**: LSP keymaps are automatically set up when LSP attaches to a buffer
4. **Idle Shutdown**: LSP clients are automatically shut down after inactivity to save resources

### Example Usage

```vim
" Install an LSP server
:FreemasonInstall rust_analyzer

" The LSP is automatically available for Rust files
" No additional configuration needed!
```

### Key Differences from nvim-lspconfig

| Feature | nvim-lspconfig | Freemason |
|---------|----------------|-----------|
| Configuration | Manual per-LSP config | Automatic from adapters |
| Keymaps | Manual setup required | Automatic setup |
| Installation | Separate tool management | Integrated installation |
| Idle shutdown | Not included | Built-in with config |
| Diagnostics | Manual setup | Automatic configuration |

### Custom LSP Configuration

You can override LSP settings using the `overrides` option:

```lua
require('freemason').setup({
  overrides = {
    lua_ls = {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } }
        }
      }
    },
    rust_analyzer = {
      settings = {
        ["rust-analyzer"] = {
          checkOnSave = { command = "clippy" }
        }
      }
    }
  }
})
```



## Troubleshooting

### Common Issues

**Q: UI is slow to open for the first time**
A: This is normal - the registry compiles on first access. Subsequent opens are instant.

**Q: Tool installation fails**
A: Check that you have the required dependencies (curl, tar, unzip, etc.) and internet connection.

**Q: LSP not working after installation**
A: Try restarting Neovim or manually enabling the LSP with `:lua vim.lsp.enable("server_name")`.

**Q: Cache issues**
A: Clear the cache with `:FreemasonCache clear`.

**Q: "External repositories not configured" message**
A: This is normal if you haven't cloned with submodules. The plugin will still work with basic functionality. For full access to 500+ tools, clone with `git clone --recursive`.

### Debug Mode

Enable debug logging:

```lua
vim.lsp.set_log_level("debug")
```

## Development

### Architecture

Freemason uses an adapter pattern to integrate external data sources:

```
freemason/
├── adapters/           # External data adapters
│   ├── lspconfig.lua   # nvim-lspconfig adapter
│   └── mason_registry.lua # mason-registry adapter
├── registry/           # Tool registry management
├── installer/          # Tool installation logic
├── ui/                 # User interface
└── launcher.lua        # LSP client management
```

### Adding New Tools

1. Add tool definition to `registry/packages/`
2. Add LSP config to `lsp/configs/` (if applicable)
3. Test installation and functionality

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) for LSP configurations
- [mason-registry](https://github.com/williamboman/mason-registry) for tool definitions
- [Mason.nvim](https://github.com/williamboman/mason.nvim) for inspiration

This is my first plugin I've developed and as a result I used a lot of different external resources like blogs, reddit, youtube, even AI for logic of some files.
Unfortunately I didn't document the resources I used so I just wanna say thank you to the whole community.
