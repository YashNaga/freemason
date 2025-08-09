-- Local LSP configuration for lua_ls
-- This is a sample configuration that can be customized

return {
    cmd = { vim.fn.stdpath("data") .. "/freemason/bin/lua-language-server" },
    filetypes = { "lua" },
    root_dir = vim.fn.getcwd(),
    settings = {
        Lua = {
            runtime = {
                version = "LuaJIT",
                path = vim.split(package.path, ";"),
            },
            diagnostics = {
                globals = { "vim" },
            },
            workspace = {
                library = {
                    [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                    [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
                },
            },
            telemetry = {
                enable = false,
            },
        },
    },
}
