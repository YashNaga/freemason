local M = {}

--- Setup diagnostics configuration
---@param diagnostics_config table
function M.setup_diagnostics(diagnostics_config)
    if not diagnostics_config then
        return
    end

    -- Configure diagnostic display
    if diagnostics_config.signs then
        vim.diagnostic.config({
            signs = {
                active = true,
                values = {
                    { name = "DiagnosticSignError", text = " " },
                    { name = "DiagnosticSignWarn", text = " " },
                    { name = "DiagnosticSignHint", text = " " },
                    { name = "DiagnosticSignInfo", text = " " },
                },
            },
            underline = diagnostics_config.underline ~= false,
            virtual_text = diagnostics_config.virtual_text ~= false,
            update_in_insert = diagnostics_config.update_in_insert or false,
        })
    end

    -- Configure diagnostic severity
    if diagnostics_config.severity then
        for severity, config in pairs(diagnostics_config.severity) do
            if config.sign then
                vim.fn.sign_define(
                    "DiagnosticSign" .. severity,
                    { text = config.sign, texthl = "DiagnosticSign" .. severity }
                )
            end
        end
    end
end

return M
