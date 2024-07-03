-- Initialize paths and options
vim.opt.rtp:prepend(vim.env.LAZY)
vim.opt.rtp:prepend(vim.fn.fnamemodify(".", ":p:h"))

local Lazy = require("lazy")
local M = {}
local proxied_opts = {}

-- Setup function to initialize options
function M.setup(opts)
    proxied_opts = opts
    proxied_opts.pkg = { enabled = false }
    proxied_opts.lockfile = opts.lockfile or vim.fn.fnamemodify("lazy-lock.json", ":p")
end

-- Temporarily load the module
package.loaded["lazy"] = M

-- Execute the main configuration file
dofile("init.lua")

-- Restore the original lazy module
package.loaded["lazy"] = Lazy

-- Load necessary modules
local Config = require("lazy.core.config")
local Util = require("lazy.core.util")

-- Extend configuration options
Config.options = vim.tbl_deep_extend("force", Config.defaults, proxied_opts or {})

-- Normalize spec if it's a string
if type(Config.options.spec) == "string" then
    Config.options.spec = { import = Config.options.spec }
end

-- Normalize lockfile and readme paths
Config.options.lockfile = Util.norm(Config.options.lockfile)
Config.options.readme.root = Util.norm(Config.options.readme.root)

-- Set and normalize the main environment variable
Config.me = vim.env.LAZY
Config.me = Util.norm(vim.fn.fnamemodify(Config.me, ":p:h:h:h:h"))

-- Load additional core modules
local Plugins = require("lazy.core.plugin")
local Lock = require("lazy.manage.lock")

-- Load plugins
Plugins.load()

local plugins = vim.tbl_map(function(plugin)
    local lock = Lock.get(plugin)
    plugin.commit = lock.commit
    plugin.branch = lock.branch

    return {
        commit = lock.commit,
        branch = lock.branch,
        dir = plugin.dir,
        url = plugin.url,
    }
end, vim.deepcopy(Config.plugins))

print(vim.json.encode(plugins))
