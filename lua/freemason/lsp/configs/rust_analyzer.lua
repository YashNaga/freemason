-- Local LSP configuration for rust_analyzer
-- This is a sample configuration that can be customized

return {
    cmd = { vim.fn.stdpath("data") .. "/freemason/bin/rust-analyzer" },
    filetypes = { "rust" },
    root_dir = vim.fn.getcwd(),
    settings = {
        ["rust-analyzer"] = {
            cargo = {
                loadOutDirsFromCheck = true,
            },
            procMacro = {
                enable = true,
            },
        },
    },
}
