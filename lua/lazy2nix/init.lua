local M = {}

-- Convinces vimrc that `lazy.nvim` is available
function M.proxy_fs_stat(lazy)
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    local uv_or_loop = (vim.uv or vim.loop)
    local original_fs_stat = uv_or_loop.fs_stat
    ---@diagnostic disable-next-line: duplicate-set-field
    function uv_or_loop.fs_stat(path, ...)
        if path == lazypath then
            path = lazy or vim.env.LAZY
        end

        return original_fs_stat(path, ...)
    end
end

function M.load_vimrc(vimrc_path)
    -- Prepend the runtime path with the config modules path
    vim.opt.rtp:prepend(vimrc_path)

    -- Execute the actual vimrc file
    dofile(vimrc_path .. "init.lua")
end

function M.proxy_lazy_setup(lazy_module, callback)
    local original_lazy_setup = lazy_module.setup
    lazy_module.setup = function(spec, opts)
        -- Determine if `spec` is a table containing the `spec` key
        if type(spec) == "table" and spec.spec then
            opts = spec
        else
            opts = opts or {}
            opts.spec = spec
        end

        callback(opts, original_lazy_setup)
    end
end

return M
