local M = {}

M._user_config = {}

M.defaults = {
    ui = {
        auto_open = false, -- Open Freemason UI at startup
        border = "rounded", -- Border style for UI windows
        show_status_icons = true, -- Show ✓ ✗ ? icons in UI
        show_versions = true, -- Show installed/version info in UI
        show_filter = true, -- Show tool category filters
        width = 0.6,
        height = 0.7, -- 6 7
        icons = {
            installed = "✓", -- Icon for installed tools
            not_installed = "✗", -- Icon for not installed tools
            pending = "…" -- Icon for tools pending installation
        },
    },

    install = {
        root_dir = vim.fn.stdpath("data") .. "/freemason/packages", -- Where tools are installed
        auto_update = false,                                        -- Auto-update tools at startup
        lockfile = "freemason-lock.json",                           -- Path to lockfile
        symlink_bins = true,                                        -- Whether to symlink binaries to a central bin dir
        bin_dir = vim.fn.stdpath("data") .. "/freemason/bin",       -- Where symlinks are stored
    },

    hooks = {
        enable = true, -- Whether to fire FreemasonSetupHook autocmd
    },

    -- LSP configuration
    lsp = {
        -- Idle shutdown settings (mimics garbage-day.nvim)
        idle_shutdown = {
            enabled = true,         -- Enable idle shutdown
            timeout = 300000,       -- Shutdown after 5 minutes of inactivity (in ms)
            check_interval = 60000, -- Check every minute (in ms)
            exclude_filetypes = {}, -- Filetypes to exclude from idle shutdown
            exclude_buftypes = {    -- Buftypes to exclude from idle shutdown
                "nofile",
                "prompt",
                "quickfix",
                "help",
                "terminal"
            },
        },

        -- LSP keymaps configuration
        -- These keymaps are automatically set up when LSP attaches to a buffer
        keymaps = {
            enabled = true,  -- Enable/disable LSP keymaps
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
                ["<leader>do"] = { "vim.diagnostic.open_float", "Show diagnostic" },
            }
        },

        -- Diagnostic configuration
        diagnostics = {
            enabled = true,  -- Enable/disable diagnostic configuration
            
            -- Signs configuration (icons in gutter)
            signs = {
                enabled = true,  -- Enable diagnostic signs
                -- Use nerd font icons if available, fallback to text
                text = {
                    [vim.diagnostic.severity.ERROR] = '󰅚 ',
                    [vim.diagnostic.severity.WARN] = '󰀪 ',
                    [vim.diagnostic.severity.INFO] = '󰋽 ',
                    [vim.diagnostic.severity.HINT] = '󰌶 ',
                },
                -- Fallback text for non-nerd fonts
                text_fallback = {
                    [vim.diagnostic.severity.ERROR] = 'E',
                    [vim.diagnostic.severity.WARN] = 'W',
                    [vim.diagnostic.severity.INFO] = 'I',
                    [vim.diagnostic.severity.HINT] = 'H',
                },
            },
            
            -- Virtual text configuration (inline messages)
            virtual_text = {
                enabled = true,  -- Enable virtual text
                source = 'if_many',  -- Show source if multiple diagnostics
                spacing = 2,  -- Spacing between virtual text and code
                format = nil,  -- Custom format function (nil = use default)
            },
            
            -- Underline configuration
            underline = {
                enabled = true,  -- Enable underlines
                severity = vim.diagnostic.severity.ERROR,  -- Only underline errors by default
            },
            
            -- Float configuration (popup on hover)
            float = {
                enabled = true,  -- Enable diagnostic float
                border = 'rounded',  -- Border style
                source = 'if_many',  -- Show source if multiple diagnostics
            },
            
            -- General diagnostic settings
            severity_sort = true,  -- Sort diagnostics by severity
        },

        -- Debug settings
        debug = false, -- Enable debug output
    },

    overrides = {
        -- tool_name = {
        --   opts = { custom config },
        --   config = function(tool) end
        -- }
    },

    -- External repository configuration (will be set dynamically in init.lua)
    registry = {
        lspconfig_path = nil,        -- Will be set to absolute path in init.lua
        mason_registry_path = nil    -- Will be set to absolute path in init.lua
    }
}

--- Accept user config and apply it over defaults
function M.setup(user_opts)
    -- Support both old-style config and new opts-style
    local opts = user_opts or {}
    
    -- Handle opts-style configuration (for Lazy.nvim)
    if opts.lua_ls then
        -- Convert lua_ls config to overrides format
        opts.overrides = opts.overrides or {}
        opts.overrides.lua_ls = opts.lua_ls
        opts.lua_ls = nil -- Remove from top level
    end
    
    -- Handle idle_shutdown at top level
    if opts.idle_shutdown ~= nil then
        opts.lsp = opts.lsp or {}
        opts.lsp.idle_shutdown = opts.idle_shutdown
        opts.idle_shutdown = nil -- Remove from top level
    end
    
    M._user_config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
end

--- Returns the full merged config
function M.get()
    return M._user_config
end

return M
