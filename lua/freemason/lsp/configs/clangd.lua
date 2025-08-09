-- Local LSP configuration for clangd
-- This is a sample configuration that can be customized

return {
    cmd = { vim.fn.stdpath("data") .. "/freemason/bin/clangd" },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_dir = vim.fn.getcwd(),
    settings = {
        clangd = {
            arguments = {
                "--background-index",
                "--clang-tidy",
                "--header-insertion=iwyu",
                "--completion-style=detailed",
                "--fallback-style=Google",
            },
        },
    },
}
