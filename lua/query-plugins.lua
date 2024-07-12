-- Prepend the runtime path with the necessary directories
vim.opt.rtp:prepend(vim.env.LAZY)
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
vim.opt.rtp:prepend(vim.fn.fnamemodify(".", ":p:h"))

-- Load the `lazy` module
require("lazy")

-- Proxy the `lazy` setup function
package.loaded["lazy"].setup = function(opts)
    -- Initialize options if not provided
    opts = opts or {}

    -- Disable the package manager and set lockfile path
    opts.pkg = { enabled = false }
    opts.lockfile = vim.fn.fnamemodify(opts.lockfile or "lazy-lock.json", ":p")

    -- Load required modules
    local Config = require("lazy.core.config")
    local Util = require("lazy.core.util")

    -- Extend configuration options with provided options
    Config.options = vim.tbl_deep_extend("force", Config.defaults, opts)

    -- Normalize `spec` if it's a string
    if type(Config.options.spec) == "string" then
        Config.options.spec = { import = Config.options.spec }
    end

    -- Normalize readme paths (as `lazy` does it)
    Config.options.readme.root = Util.norm(Config.options.readme.root)

    -- Allow `lazy` to locate itself
    Config.me = vim.env.LAZY

    -- Load required modules for plugin management
    local Plugins = require("lazy.core.plugin")
    local Lock = require("lazy.manage.lock")

    -- Parse the plugin spec
    Plugins.load()

    -- Process plugins and gather information
    local plugins = vim.tbl_map(function(plugin)
        local lock = Lock.get(plugin)
        plugin.commit = lock.commit
        plugin.branch = lock.branch

        return {
            commit = lock.commit,
            branch = lock.branch,
            url = plugin.url,
        }
    end, vim.deepcopy(Config.plugins))

    -- Write plugin information to the specified output file
    local output_file = assert(io.open(vim.env.out, "wb"))
    output_file:write(vim.json.encode(plugins))
    output_file:close()

    -- Exit the script
    os.exit()
end

-- Execute the vimrc file
dofile("init.lua")
