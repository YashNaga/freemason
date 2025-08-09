local uv = vim.loop
local registry = require("freemason.registry")
local config = require("freemason.config")

local M = {}

local install_dir = vim.fn.stdpath("data") .. "/freemason/packages"
local bin_dir = vim.fn.stdpath("data") .. "/freemason/bin"

-- Ensure bin dir exists
local function ensure_bin_dir()
    if not uv.fs_stat(bin_dir) then
        uv.fs_mkdir(bin_dir, 448) -- 0700
    end
end

-- Platform detection with aliases
local function get_platform_aliases()
    local uname = vim.loop.os_uname()
    local sys = uname.sysname:lower()
    local arch = uname.machine:lower()
    local aliases = {}

    if sys:find("darwin") or sys:find("mac") or sys:find("osx") then
        if arch:find("arm") or arch:find("aarch64") then
            aliases = { "darwin_arm64", "macos_arm64", "osx_arm64" }
        else
            aliases = { "darwin_x64", "macos_x64", "osx_x64" }
        end
    elseif sys:find("linux") then
        if arch:find("arm64") or arch:find("aarch64") then
            aliases = { "linux_arm64_gnu", "linux_arm64", "linux_aarch64" }
        elseif arch:find("x86_64") then
            aliases = { "linux_x64_gnu", "linux_x64", "linux_amd64" }
        elseif arch:find("musl") then
            aliases = { "linux_x64_musl" }
        end
    elseif sys:find("windows") then
        if arch:find("arm") then
            aliases = { "win_arm64", "windows_arm64" }
        else
            aliases = { "win_x64", "windows_x64", "win32_x64" }
        end
    end
    return aliases
end

local function get_asset_for_platform(tool_meta)
    local version = tool_meta.version or
    (tool_meta.source and tool_meta.source.id and tool_meta.source.id:match("@(.+)$")) or "latest"
    local assets = {}

    if not tool_meta or not tool_meta.source then
        return nil
    end

    -- Check version_overrides first
    if tool_meta.source and tool_meta.source.version_overrides then
        for _, override in ipairs(tool_meta.source.version_overrides) do
            if override.id and override.id:match("@" .. version) then
                assets = override.asset or {}
                break
            end
        end
    end

    -- Fallback to top-level asset if no override matched
    if #assets == 0 and tool_meta.source and tool_meta.source.asset then
        assets = tool_meta.source.asset
    end

    local aliases = get_platform_aliases()
    for _, alias in ipairs(aliases) do
        for _, asset in ipairs(assets) do
            -- Handle both string and array targets
            if type(asset.target) == "string" and asset.target == alias then
                return asset
            elseif type(asset.target) == "table" then
                for _, target in ipairs(asset.target) do
                    if target == alias then
                        return asset
                    end
                end
            end
        end
    end
    return nil
end

local function find_binary(install_path, bin_name)
    -- Try asset.bin first
    local candidate = install_path .. "/" .. bin_name
    if uv.fs_stat(candidate) then
        return candidate
    end
    -- Fallback: search recursively for a file matching bin_name
    local function scan_dir(dir)
        for entry in vim.fs.dir(dir) do
            local full_path = dir .. "/" .. entry
            local stat = uv.fs_stat(full_path)
            if stat then
                if stat.type == "file" and entry == bin_name then
                    return full_path
                elseif stat.type == "directory" then
                    local found = scan_dir(full_path)
                    if found then return found end
                end
            end
        end
        return nil
    end
    return scan_dir(install_path)
end

-- Create symlink for binary in central bin dir
local function link_binary(tool_meta, asset)
    ensure_bin_dir()
    local install_path = install_dir .. "/" .. tool_meta.name

    -- Determine bin_name
    local bin_name = asset and asset.bin or tool_meta.bin
    if type(bin_name) == "table" then
        local first_key = next(bin_name)
        bin_name = first_key or tool_meta.name
    end
    if type(bin_name) ~= "string" then
        bin_name = tool_meta.name
    end
    
    -- Handle different binary path patterns
    local actual_bin_name = bin_name
    if bin_name:match("{{source%.asset%.file}}") then
        -- For packages where the binary is the file itself (like marksman)
        actual_bin_name = tool_meta.name
    elseif bin_name:match("{{source%.asset%.bin}}") then
        -- For packages where the binary is in a subdirectory
        actual_bin_name = vim.fn.fnamemodify(bin_name, ":t")
    elseif bin_name:match("^exec:") then
        -- Handle exec: prefix (like "exec:libexec/bin/lua-language-server")
        actual_bin_name = vim.fn.fnamemodify(bin_name:gsub("^exec:", ""), ":t")
    else
        -- For packages with explicit binary paths
        actual_bin_name = vim.fn.fnamemodify(bin_name, ":t")
    end

    local bin_path = nil
    local dst = bin_dir .. "/" .. actual_bin_name

    -- Handle different source types
    if tool_meta.source and tool_meta.source.id then
        local source_id = tool_meta.source.id
        
        if source_id:match("^pkg:npm/") then
            -- For NPM packages, use the local installation path
            bin_path = install_path .. "/node_modules/.bin/" .. actual_bin_name
            if not uv.fs_stat(bin_path) then
                -- Try alternative locations
                bin_path = install_path .. "/node_modules/" .. actual_bin_name .. "/bin/" .. actual_bin_name
                if not uv.fs_stat(bin_path) then
                    bin_path = install_path .. "/node_modules/" .. actual_bin_name .. "/" .. actual_bin_name
                end
            end
        elseif source_id:match("^pkg:golang/") then
            -- For Go packages, use the local installation path
            bin_path = install_path .. "/bin/" .. actual_bin_name
            if not uv.fs_stat(bin_path) then
                -- Try alternative names
                bin_path = install_path .. "/bin/" .. (tool_meta.bin and tool_meta.bin[1] or tool_meta.name)
            end
        else
            -- For GitHub releases, handle exec: prefix in binary path
            if bin_name:match("^exec:") then
                -- For exec: paths, construct the full path
                local exec_path = bin_name:gsub("^exec:", "")
                bin_path = install_path .. "/" .. exec_path
            else
                -- Use the existing logic
                bin_path = find_binary(install_path, actual_bin_name)
            end
        end
    else
        -- Fallback to existing logic
        bin_path = find_binary(install_path, actual_bin_name)
    end

    if not bin_path or not uv.fs_stat(bin_path) then
        vim.notify(string.format("[Freemason] Could not find binary for %s", tool_meta.name), vim.log.levels.ERROR)
        return
    end

    if uv.fs_stat(dst) then
        uv.fs_unlink(dst)
    end

    -- Special handling for lua-language-server: create a wrapper script
    if tool_meta.name == "lua-language-server" then
        -- Create wrapper script content
        local wrapper_content = string.format([[
#!/bin/sh
cd "%s"
exec "%s" "$@"
]], vim.fn.fnamemodify(bin_path, ":h:h"), bin_path)
        
        -- Write wrapper script
        local file = io.open(dst, "w")
        if not file then
            vim.notify(string.format("[Freemason] Failed to create wrapper script for %s", actual_bin_name), vim.log.levels.WARN)
            return
        end
        file:write(wrapper_content)
        file:close()
        
        -- Make wrapper script executable
        uv.fs_chmod(dst, 493) -- 0o755 in decimal
    else
        -- For other binaries, create symlink
        local ok, err = uv.fs_symlink(vim.fn.resolve(bin_path), dst, 0)
        if not ok then
            vim.notify(string.format("[Freemason] Failed to link binary %s", actual_bin_name), vim.log.levels.WARN)
        end
    end
end

-- Remove symlink for binary
local function unlink_binary(tool_meta, asset)
    -- Use the same logic as link_binary to determine bin_name
    local bin_name = asset and asset.bin or tool_meta.bin
    if type(bin_name) == "table" then
        local first_key = next(bin_name)
        bin_name = first_key or tool_meta.name
    end
    if type(bin_name) ~= "string" then
        bin_name = tool_meta.name
    end
    
    -- Handle different binary path patterns
    local actual_bin_name = bin_name
    if bin_name:match("{{source%.asset%.file}}") then
        -- For packages where the binary is the file itself (like marksman)
        actual_bin_name = tool_meta.name
    elseif bin_name:match("{{source%.asset%.bin}}") then
        -- For packages where the binary is in a subdirectory
        actual_bin_name = vim.fn.fnamemodify(bin_name, ":t")
    elseif bin_name:match("^exec:") then
        -- Handle exec: prefix (like "exec:libexec/bin/lua-language-server")
        actual_bin_name = vim.fn.fnamemodify(bin_name:gsub("^exec:", ""), ":t")
    else
        -- For packages with explicit binary paths
        actual_bin_name = vim.fn.fnamemodify(bin_name, ":t")
    end

    local dst = bin_dir .. "/" .. actual_bin_name
    if uv.fs_stat(dst) then
        uv.fs_unlink(dst)
    end
end

-- Finalize installation: update lockfile, create symlink, notify user
local function finalize_install(tool_meta, asset, version)
    local lockfile = require("freemason.lockfile")
    version = version or "latest"
    lockfile.add({
        name = tool_meta.name,
        version = version,
        bin = tool_meta.bin,
        installed = true,
    })
    link_binary(tool_meta, asset)
    
    -- Re-register the LSP after installation
    local lsp_name = tool_meta.name
    if lsp_name == "lua-language-server" then
        lsp_name = "lua_ls"
    elseif lsp_name == "typescript-language-server" then
        lsp_name = "tsserver"
    end
    
    local launcher = require("freemason.launcher")
    if launcher and launcher.register_lsp then
        pcall(launcher.register_lsp, lsp_name)
    end
    
    -- Update tool status in compiled registry
    local registry_cache = require("freemason.registry_cache")
    if registry_cache then
        pcall(registry_cache.update_tool_status, tool_meta.name, true, version, false)
    end
    
    vim.schedule(function()
        vim.notify(string.format("[Freemason] Installed %s", tool_meta.name), vim.log.levels.INFO)
    end)
end

-- Finalize uninstall: update lockfile, remove symlink, stop LSP, notify user
local function finalize_uninstall(tool_meta)
    local lockfile = require("freemason.lockfile")
    lockfile.remove(tool_meta.name)
    unlink_binary(tool_meta)
    
    -- Stop LSP client if it's running
    local lsp_name = tool_meta.name
    -- Handle special cases for LSP names
    if lsp_name == "lua-language-server" then
        lsp_name = "lua_ls"
    elseif lsp_name == "typescript-language-server" then
        lsp_name = "tsserver"
    end
    
    -- Stop the LSP client more aggressively
    pcall(vim.lsp.enable, lsp_name, false)
    
    -- Stop any active clients for this LSP
    local clients = vim.lsp.get_clients()
    for _, client in pairs(clients) do
        if client.name == lsp_name then
            pcall(client.stop)
        end
    end
    
    -- Also try to stop using the launcher if available
    local launcher = require("freemason.launcher")
    if launcher and launcher.stop_lsp_client then
        -- Get all clients and stop the ones matching this LSP
        local all_clients = vim.lsp.get_clients()
        for _, client in pairs(all_clients) do
            if client.name == lsp_name then
                pcall(launcher.stop_lsp_client, client.id)
            end
        end
    end
    
    -- Force stop all clients with this name
    vim.schedule(function()
        local running_clients = vim.lsp.get_clients()
        for _, client in pairs(running_clients) do
            if client.name == lsp_name then
                vim.notify("[Freemason] Stopping LSP client: " .. client.name, vim.log.levels.INFO)
                pcall(client.stop)
            end
        end
    end)
    
    -- Remove the LSP configuration registration
    -- This prevents Neovim from trying to start the LSP again
    local launcher = require("freemason.launcher")
    if launcher and launcher.unregister_lsp then
        pcall(launcher.unregister_lsp, lsp_name)
    else
        pcall(vim.lsp.config, lsp_name, nil)
    end
    
    -- Remove autocmds that auto-start this LSP
    local freemason = require("freemason")
    if freemason.remove_lsp_autocmds then
        pcall(freemason.remove_lsp_autocmds, lsp_name)
    end
    
    -- Update tool status in compiled registry
    local registry_cache = require("freemason.registry_cache")
    if registry_cache then
        pcall(registry_cache.update_tool_status, tool_meta.name, false, nil, false)
    end
    
    -- Invalidate cache after uninstallation
    local registry_cache = require("freemason.registry_cache")
    if registry_cache then
        pcall(registry_cache.invalidate_all)
    end
    
    vim.schedule(function()
        vim.notify(string.format("[Freemason] Uninstalled %s", tool_meta.name), vim.log.levels.INFO)
    end)
end

-- Install from GitHub releases
local function install_from_github(tool_meta, callback)
    local asset = get_asset_for_platform(tool_meta)
    local platform = get_platform_aliases()[1]
    if not asset then
        vim.notify("[Freemason] No asset for platform: " .. (platform or "unknown"), vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end

    local version = tool_meta.version or
    (tool_meta.source and tool_meta.source.id and tool_meta.source.id:match("@(.+)$")) or "latest"
    local file_template = asset.file
    local file_name = file_template:gsub("{{version}}", version):match("^[^:]+")
    print("file_template:", file_template)
    print("parsed file_name:", file_name)
    local url

    -- Try to construct GitHub release URL from source.id
    if tool_meta.source and tool_meta.source.id then
        local pkg = tool_meta.source.id
        local owner, name, ver = pkg:match("pkg:github/([^/]+)/([^@]+)@(.+)")
        if owner and name and ver then
            url = string.format("https://github.com/%s/%s/releases/download/%s/%s", owner, name, ver, file_name)
        end
    end

    if not url then
        vim.notify("[Freemason] Could not construct GitHub download URL for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end

    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    local archive_path = install_path .. "/" .. file_name

    -- Download
    local curl_cmd = { "curl", "-L", "-o", archive_path, url }
    vim.fn.system(curl_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Download failed: " .. url, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end

    -- Extract
    if file_name:match("%.tar%.gz$") then
        -- Check if we need to extract to a subdirectory
        local extract_path = install_path
        local subdir = asset.file and asset.file:match(":(.+)$")
        if subdir then
            extract_path = install_path .. "/" .. subdir
            vim.fn.mkdir(extract_path, "p")
        end
        
        local tar_cmd = { "tar", "xzf", archive_path, "-C", extract_path }
        vim.fn.system(tar_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("[Freemason] Extraction failed: " .. archive_path, vim.log.levels.ERROR)
            if callback then callback(false) end
            return
        end
        
        -- Handle binary path from asset.bin
        if asset.bin then
            local bin_path = asset.bin
            if bin_path:match("^exec:") then
                -- Handle exec: prefix (like "exec:libexec/bin/lua-language-server")
                bin_path = bin_path:gsub("^exec:", "")
                local full_bin_path = install_path .. "/" .. bin_path
                if vim.fn.filereadable(full_bin_path) == 1 then
                    vim.fn.system(string.format("chmod +x %s", full_bin_path))
                end
            elseif bin_path:match("^bin/") then
                -- Handle bin/ prefix
                local full_bin_path = install_path .. "/" .. bin_path
                if vim.fn.filereadable(full_bin_path) == 1 then
                    vim.fn.system(string.format("chmod +x %s", full_bin_path))
                end
            end
        end
    elseif file_name:match("%.zip$") then
        -- Check if we need to extract to a subdirectory
        local extract_path = install_path
        local subdir = asset.file and asset.file:match(":(.+)$")
        if subdir then
            extract_path = install_path .. "/" .. subdir
            vim.fn.mkdir(extract_path, "p")
        end
        
        local unzip_cmd = { "unzip", "-o", archive_path, "-d", extract_path }
        vim.fn.system(unzip_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("[Freemason] Extraction failed: " .. archive_path, vim.log.levels.ERROR)
            if callback then callback(false) end
            return
        end
        
        -- Handle binary path from asset.bin
        if asset.bin then
            local bin_path = asset.bin
            if bin_path:match("^bin/") then
                local full_bin_path = install_path .. "/" .. bin_path
                if vim.fn.filereadable(full_bin_path) == 1 then
                    vim.fn.system(string.format("chmod +x %s", full_bin_path))
                end
            end
        end
    elseif file_name:match("%.gz$") then
        -- Handle gzipped binaries (like rust-analyzer)
        local gunzip_cmd = { "gunzip", "-f", archive_path }
        vim.fn.system(gunzip_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("[Freemason] Extraction failed: " .. archive_path, vim.log.levels.ERROR)
            if callback then callback(false) end
            return
        end
        -- Move the extracted binary to the install path
        local extracted_name = file_name:gsub("%.gz$", "")
        local extracted_path = install_path .. "/" .. extracted_name
        local final_path = install_path .. "/" .. (asset.bin or extracted_name)
        vim.fn.system(string.format("mv %s %s", extracted_path, final_path))
        vim.fn.system(string.format("chmod +x %s", final_path))
    else
        -- Handle plain binaries (like marksman)
        local final_path = install_path .. "/" .. (asset.bin or tool_meta.name)
        if archive_path ~= final_path then
            vim.fn.system(string.format("mv %s %s", archive_path, final_path))
        end
        vim.fn.system(string.format("chmod +x %s", final_path))
    end

    if callback then callback(true, asset) end
end

-- Install from NPM
local function install_from_npm(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:npm/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:npm/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse NPM package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install locally using npm
    local package_json_path = install_path .. "/package.json"
    local package_json = {
        name = tool_meta.name,
        version = "1.0.0",
        dependencies = {}
    }
    package_json.dependencies[package_name] = version
    
    -- Write package.json
    local file = io.open(package_json_path, "w")
    if file then
        file:write(vim.json.encode(package_json))
        file:close()
    end
    
    -- Install using npm
    local npm_cmd = { "npm", "install", "--prefix", install_path }
    vim.fn.system(npm_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] NPM installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in node_modules
    local bin_path = install_path .. "/node_modules/.bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative locations
        bin_path = install_path .. "/node_modules/" .. package_name .. "/bin/" .. package_name
        if vim.fn.filereadable(bin_path) == 0 then
            bin_path = install_path .. "/node_modules/" .. package_name .. "/" .. package_name
        end
    end
    
    -- Create a mock asset for NPM packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from Go modules
local function install_from_golang(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract module path and version from source.id
    local pkg = tool_meta.source.id
    local module_path, version = pkg:match("pkg:golang/([^@]+)@(.+)")
    if not module_path then
        module_path = pkg:match("pkg:golang/(.+)")
        version = "latest"
    end
    
    if not module_path then
        vim.notify("[Freemason] Could not parse Go module path for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Create go.mod file
    local go_mod_path = install_path .. "/go.mod"
    local go_mod_content = string.format("module %s\n\ngo 1.21\n\nrequire %s %s\n", tool_meta.name, module_path, version)
    local file = io.open(go_mod_path, "w")
    if file then
        file:write(go_mod_content)
        file:close()
    end
    
    -- Install using go install with local GOPATH
    local original_gopath = vim.env.GOPATH
    vim.env.GOPATH = install_path
    
    local go_cmd = { "go", "install", module_path .. "@" .. version }
    vim.fn.system(go_cmd)
    
    -- Restore original GOPATH
    if original_gopath then
        vim.env.GOPATH = original_gopath
    else
        vim.env.GOPATH = nil
    end
    
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Go installation failed for " .. module_path, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in bin directory
    local bin_path = install_path .. "/bin/" .. tool_meta.name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/bin/" .. (tool_meta.bin and tool_meta.bin[1] or tool_meta.name)
    end
    
    -- Create a mock asset for Go packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from Cargo (Rust)
local function install_from_cargo(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:cargo/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:cargo/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse Cargo package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install using cargo
    local cargo_cmd = { "cargo", "install", "--root", install_path, package_name }
    if version and version ~= "latest" then
        table.insert(cargo_cmd, "--version")
        table.insert(cargo_cmd, version)
    end
    
    vim.fn.system(cargo_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Cargo installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in bin directory
    local bin_path = install_path .. "/bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/bin/" .. tool_meta.name
    end
    
    -- Create a mock asset for Cargo packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from PyPI (Python)
local function install_from_pypi(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:pypi/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:pypi/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse PyPI package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install using pip
    local pip_cmd = { "pip", "install", "--target", install_path }
    if version and version ~= "latest" then
        table.insert(pip_cmd, package_name .. "==" .. version)
    else
        table.insert(pip_cmd, package_name)
    end
    
    vim.fn.system(pip_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] PyPI installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in bin directory
    local bin_path = install_path .. "/bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/bin/" .. tool_meta.name
    end
    
    -- Create a mock asset for PyPI packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from RubyGems
local function install_from_gem(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:gem/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:gem/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse Gem package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install using gem
    local gem_cmd = { "gem", "install", "--install-dir", install_path }
    if version and version ~= "latest" then
        table.insert(gem_cmd, package_name .. ":" .. version)
    else
        table.insert(gem_cmd, package_name)
    end
    
    vim.fn.system(gem_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Gem installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in bin directory
    local bin_path = install_path .. "/bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/bin/" .. tool_meta.name
    end
    
    -- Create a mock asset for Gem packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from Composer (PHP)
local function install_from_composer(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:composer/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:composer/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse Composer package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Create composer.json
    local composer_json_path = install_path .. "/composer.json"
    local composer_json = {
        name = tool_meta.name,
        require = {}
    }
    composer_json.require[package_name] = version
    
    -- Write composer.json
    local file = io.open(composer_json_path, "w")
    if file then
        file:write(vim.json.encode(composer_json))
        file:close()
    end
    
    -- Install using composer
    local composer_cmd = { "composer", "install", "--working-dir", install_path }
    vim.fn.system(composer_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Composer installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in vendor/bin directory
    local bin_path = install_path .. "/vendor/bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/vendor/bin/" .. tool_meta.name
    end
    
    -- Create a mock asset for Composer packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from NuGet (.NET)
local function install_from_nuget(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:nuget/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:nuget/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse NuGet package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install using dotnet tool
    local dotnet_cmd = { "dotnet", "tool", "install", "--tool-path", install_path }
    if version and version ~= "latest" then
        table.insert(dotnet_cmd, "--version")
        table.insert(dotnet_cmd, version)
    end
    table.insert(dotnet_cmd, package_name)
    
    vim.fn.system(dotnet_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] NuGet installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in the install path
    local bin_path = install_path .. "/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/" .. tool_meta.name
    end
    
    -- Create a mock asset for NuGet packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from LuaRocks
local function install_from_luarocks(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package name and version from source.id
    local pkg = tool_meta.source.id
    local package_name, version = pkg:match("pkg:luarocks/([^@]+)@(.+)")
    if not package_name then
        package_name = pkg:match("pkg:luarocks/(.+)")
        version = "latest"
    end
    
    if not package_name then
        vim.notify("[Freemason] Could not parse LuaRocks package name for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Install using luarocks
    local luarocks_cmd = { "luarocks", "install", "--tree", install_path }
    if version and version ~= "latest" then
        table.insert(luarocks_cmd, package_name .. " " .. version)
    else
        table.insert(luarocks_cmd, package_name)
    end
    
    vim.fn.system(luarocks_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] LuaRocks installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary in bin directory
    local bin_path = install_path .. "/bin/" .. package_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try alternative names
        bin_path = install_path .. "/bin/" .. tool_meta.name
    end
    
    -- Create a mock asset for LuaRocks packages
    local mock_asset = {
        bin = bin_path
    }
    
    if callback then callback(true, mock_asset) end
end

-- Install from generic sources (fallback)
local function install_from_generic(tool_meta, callback)
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Extract package info from source.id
    local pkg = tool_meta.source.id
    local source_type, package_name, version = pkg:match("pkg:generic/([^/]+)/([^@]+)@(.+)")
    if not source_type then
        source_type, package_name = pkg:match("pkg:generic/([^/]+)/(.+)")
        version = "latest"
    end
    
    if not source_type or not package_name then
        vim.notify("[Freemason] Could not parse generic package info for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- For generic packages, we'll try to use the system package manager
    local install_cmd = nil
    
    if source_type == "haskell" then
        install_cmd = { "cabal", "install", "--prefix", install_path, package_name }
    elseif source_type == "hashicorp" then
        -- For HashiCorp tools, try to download from releases
        local url = string.format("https://releases.hashicorp.com/%s/%s/%s_%s_darwin_amd64.zip", 
            package_name, version, package_name, version)
        local archive_path = install_path .. "/" .. package_name .. ".zip"
        
        -- Download
        local curl_cmd = { "curl", "-L", "-o", archive_path, url }
        vim.fn.system(curl_cmd)
        if vim.v.shell_error == 0 then
            -- Extract
            local unzip_cmd = { "unzip", "-o", archive_path, "-d", install_path }
            vim.fn.system(unzip_cmd)
            if vim.v.shell_error == 0 then
                local bin_path = install_path .. "/" .. package_name
                vim.fn.system(string.format("chmod +x %s", bin_path))
                
                local mock_asset = { bin = bin_path }
                if callback then callback(true, mock_asset) end
                return
            end
        end
        vim.notify("[Freemason] Generic installation failed for " .. package_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    else
        vim.notify("[Freemason] Unsupported generic source type: " .. source_type, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    if install_cmd then
        vim.fn.system(install_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("[Freemason] Generic installation failed for " .. package_name, vim.log.levels.ERROR)
            if callback then callback(false) end
            return
        end
        
        -- Find the binary
        local bin_path = install_path .. "/bin/" .. package_name
        if vim.fn.filereadable(bin_path) == 0 then
            bin_path = install_path .. "/bin/" .. tool_meta.name
        end
        
        local mock_asset = { bin = bin_path }
        if callback then callback(true, mock_asset) end
    end
end

-- Install from download section (for tools like terraform)
local function install_from_download(tool_meta, callback)
    local platform = get_platform_aliases()[1]
    local download_info = nil
    
    -- Find the download info for the current platform
    if tool_meta.source and tool_meta.source.download then
        for _, download in ipairs(tool_meta.source.download) do
            if download.target and download.target:match(platform) then
                download_info = download
                break
            end
        end
    end
    
    if not download_info then
        vim.notify("[Freemason] No download info for platform: " .. (platform or "unknown"), vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    local install_path = install_dir .. "/" .. tool_meta.name
    vim.fn.mkdir(install_path, "p")
    
    -- Get the download URL and filename
    local download_url = nil
    local filename = nil
    
    for file_key, url in pairs(download_info.files) do
        filename = file_key
        download_url = url
        break
    end
    
    if not download_url then
        vim.notify("[Freemason] No download URL found for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Replace version placeholder
    local version = tool_meta.version or "latest"
    if version == "latest" and tool_meta.source.id then
        -- Extract version from source.id if available
        version = tool_meta.source.id:match("@(.+)") or "latest"
    end
    local clean_version = version:gsub("^v", "")
    download_url = download_url:gsub("{{ version | strip_prefix \"v\" }}", clean_version)
    
    local archive_path = install_path .. "/" .. filename
    
    -- Download
    local curl_cmd = { "curl", "-L", "-o", archive_path, download_url }
    vim.fn.system(curl_cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("[Freemason] Download failed: " .. download_url, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Extract
    if filename:match("%.zip$") then
        local unzip_cmd = { "unzip", "-o", archive_path, "-d", install_path }
        vim.fn.system(unzip_cmd)
        if vim.v.shell_error ~= 0 then
            vim.notify("[Freemason] Extraction failed: " .. archive_path, vim.log.levels.ERROR)
            if callback then callback(false) end
            return
        end
    else
        vim.notify("[Freemason] Unsupported archive format: " .. filename, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Find the binary
    local bin_name = download_info.bin
    local bin_path = install_path .. "/" .. bin_name
    if vim.fn.filereadable(bin_path) == 0 then
        -- Try to find it in subdirectories
        bin_path = find_binary(install_path, bin_name)
    end
    
    if not bin_path or vim.fn.filereadable(bin_path) == 0 then
        vim.notify("[Freemason] Could not find binary: " .. bin_name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Make executable
    vim.fn.system(string.format("chmod +x %s", bin_path))
    
    -- Create asset info
    local asset = {
        bin = bin_path
    }
    
    if callback then callback(true, asset) end
end

-- Generic install that routes to appropriate installer
local function generic_install(tool_meta, callback)
    if not tool_meta.source then
        vim.notify("[Freemason] No source information for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    -- Check if tool has a download section (like terraform)
    if tool_meta.source.download then
        install_from_download(tool_meta, callback)
        return
    end
    
    if not tool_meta.source.id then
        vim.notify("[Freemason] No source ID for " .. tool_meta.name, vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end
    
    local source_id = tool_meta.source.id
    
    -- Route to appropriate installer based on source type
    if source_id:match("^pkg:github/") then
        install_from_github(tool_meta, callback)
    elseif source_id:match("^pkg:npm/") then
        install_from_npm(tool_meta, callback)
    elseif source_id:match("^pkg:golang/") then
        install_from_golang(tool_meta, callback)
    elseif source_id:match("^pkg:cargo/") then
        install_from_cargo(tool_meta, callback)
    elseif source_id:match("^pkg:pypi/") then
        install_from_pypi(tool_meta, callback)
    elseif source_id:match("^pkg:gem/") then
        install_from_gem(tool_meta, callback)
    elseif source_id:match("^pkg:composer/") then
        install_from_composer(tool_meta, callback)
    elseif source_id:match("^pkg:nuget/") then
        install_from_nuget(tool_meta, callback)
    elseif source_id:match("^pkg:luarocks/") then
        install_from_luarocks(tool_meta, callback)
    elseif source_id:match("^pkg:generic/") then
        install_from_generic(tool_meta, callback)
    else
        vim.notify("[Freemason] Unsupported source type: " .. source_id, vim.log.levels.ERROR)
        if callback then callback(false) end
    end
end

--- Install tool by name (async)
---@param name string
function M.install(name)
    local lockfile = require("freemason.lockfile")
    local tool_meta = registry.get(name)
    if not tool_meta then
        vim.notify("[Freemason] Tool not found: " .. name, vim.log.levels.ERROR)
        return
    end

    if lockfile.is_listed(tool_meta.name) then
        vim.notify("[Freemason] Tool already installed: " .. name, vim.log.levels.INFO)
        return
    end

    generic_install(tool_meta, function(success, asset)
        if success then
            finalize_install(tool_meta, asset, tool_meta.version or "latest")
        else
            vim.notify("[Freemason] Failed to install " .. tool_meta.name, vim.log.levels.ERROR)
        end
    end)
end

--- Update tool by name (async)
---@param name string
function M.update(name)
    local lockfile = require("freemason.lockfile")
    local tool_meta = registry.get(name)
    if not tool_meta then
        vim.notify("[Freemason] Tool not found: " .. name, vim.log.levels.ERROR)
        return
    end

    if not lockfile.is_listed(tool_meta.name) then
        vim.notify("[Freemason] Tool not installed: " .. name .. ", installing instead.", vim.log.levels.INFO)
        M.install(name)
        return
    end

    M.uninstall(name)
    M.install(name)
end

--- Uninstall tool by name (async)
---@param name string
function M.uninstall(name)
    local lockfile = require("freemason.lockfile")
    local tool_meta = registry.get(name)
    if not tool_meta then
        vim.notify("[Freemason] Tool not found: " .. name, vim.log.levels.ERROR)
        return
    end

    if not lockfile.is_listed(tool_meta.name) then
        vim.notify("[Freemason] Tool not installed: " .. name, vim.log.levels.INFO)
        return
    end

    finalize_uninstall(tool_meta)
end

--- Get install status ("installed" or "not_installed")
---@param name string
function M.get_tool_status(name)
    local lockfile = require("freemason.lockfile")
    
    -- First check the lockfile
    if lockfile.is_listed(name) then
        return "installed"
    end
    
    -- If not in lockfile, check if the binary actually exists
    local bin_path = bin_dir .. "/" .. name
    if uv.fs_stat(bin_path) then
        -- Binary exists but not in lockfile - this could happen if plugin was reinstalled
        -- Let's add it back to the lockfile
        local tool_meta = registry.get(name)
        if tool_meta then
            local status = {
                name = name,
                version = tool_meta.version or "latest",
                installed = true
            }
            lockfile.add(status)
            return "installed"
        end
    end
    
    -- Check for alternative binary names (common variations)
    local alternative_names = {
        [name .. ".exe"] = true,  -- Windows executables
        [name .. "_" .. get_platform_aliases()[1]] = true,  -- Platform-specific names
    }
    
    for alt_name, _ in pairs(alternative_names) do
        local alt_bin_path = bin_dir .. "/" .. alt_name
        if uv.fs_stat(alt_bin_path) then
            -- Found alternative binary, add to lockfile
            local tool_meta = registry.get(name)
            if tool_meta then
                local status = {
                    name = name,
                    version = tool_meta.version or "latest",
                    installed = true,
                    bin = alt_name
                }
                lockfile.add(status)
                return "installed"
            end
        end
    end
    
    return "not_installed"
end

return M
