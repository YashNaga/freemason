local M = {}

--- Setup autocmd for LSP keymaps
---@param keymaps table
function M.setup_autocmd(keymaps)
    if not keymaps or not keymaps.enabled then
        return
    end

    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local bufnr = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            
            if not client then
                return
            end

            -- Set keymaps for the buffer
            local opts = { buffer = bufnr, noremap = true, silent = true }

            -- Default keymaps
            local default_keymaps = {
                ["gd"] = vim.lsp.buf.definition,
                ["gr"] = vim.lsp.buf.references,
                ["gi"] = vim.lsp.buf.implementation,
                ["K"] = vim.lsp.buf.hover,
                ["<C-k>"] = vim.lsp.buf.signature_help,
                ["<space>rn"] = vim.lsp.buf.rename,
                ["<space>ca"] = vim.lsp.buf.code_action,
                ["<space>f"] = vim.lsp.buf.format,
                ["[d"] = vim.diagnostic.goto_prev,
                ["]d"] = vim.diagnostic.goto_next,
            }

            -- Apply default keymaps
            for key, func in pairs(default_keymaps) do
                vim.keymap.set("n", key, func, opts)
            end

            -- Apply custom keymaps if provided
            if keymaps.custom then
                for key, func in pairs(keymaps.custom) do
                    if type(func) == "function" then
                        vim.keymap.set("n", key, func, opts)
                    elseif type(func) == "string" then
                        -- Handle string-based commands
                        vim.keymap.set("n", key, func, opts)
                    end
                end
            end
        end,
    })
end

return M
