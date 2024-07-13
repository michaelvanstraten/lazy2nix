local fnamemodify = vim.fn.fnamemodify

-- Prepend the runtime path with the `lazy2nix` module path
local function setup_lazy2nix_module()
    local script_path = debug.getinfo(1, "S").source:sub(2)
    local lazy2nix_path = fnamemodify(script_path, ":p:h:h:h")
    vim.opt.rtp:prepend(lazy2nix_path)
end

setup_lazy2nix_module()

local log = require("lazy2nix.log")

-- Ensure the vimrc path is provided as an argument
if not arg[1] then
    log.error("Please provide the vimrc path as an argument to this script.")
    os.exit(1)
end

local vimrc_path = fnamemodify(arg[1], ":p")

-- Ensure the `LAZY` environment variable is set
if not vim.env.LAZY then
    log.error("The `LAZY` environment variable is not set. Please set it to point to the `lazy.nvim` plugin.")
    os.exit(1)
end

-- Prepend the runtime path with the `lazy.nvim` module path
vim.opt.rtp:prepend(vim.env.LAZY)

-- Check if the output file path is provided as an environment variable or as a CLI argument
local output_file_path = vim.env.out or arg[2]
if not output_file_path then
    log.error("Please provide the output file path as an environment variable `out` or as a second argument.")
    os.exit(1)
end

-- Load the `lazy` module
require("lazy")

-- Proxy the `lazy` setup function to customize setup options
package.loaded["lazy"].setup = function(options)
    -- Initialize options if not provided
    options = options or {}

    -- Disable the package manager and set lockfile path
    options.pkg = { enabled = false }
    options.lockfile = fnamemodify(options.lockfile or (vimrc_path .. "lazy-lock.json"), ":p")

    -- Load required modules
    local Config = require("lazy.core.config")
    local Util = require("lazy.core.util")

    -- Extend configuration options with provided options
    Config.options = vim.tbl_deep_extend("force", Config.defaults, options)

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
        local lock_info = Lock.get(plugin)
        plugin.commit = lock_info.commit
        plugin.branch = lock_info.branch

        return {
            commit = lock_info.commit,
            branch = lock_info.branch,
            url = plugin.url,
        }
    end, vim.deepcopy(Config.plugins))

    -- Write plugin information to the specified output file
    local output_file = assert(io.open(output_file_path, "wb"))
    output_file:write(vim.json.encode(plugins))
    output_file:close()

    -- Exit the script
    os.exit()
end

-- Convince vimrc that `lazy` is available by setting up a temporary data directory
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.fn.mkdir(vim.fn.stdpath("data") .. "/lazy/lazy.nvim", "p")

-- Prepend the runtime path with the vimrc path
vim.opt.rtp:prepend(vimrc_path)

-- Execute the actual vimrc file
dofile(vimrc_path .. "init.lua")

-- Error if lazy.setup was not called by the vimrc
log.error("The provided vimrc did not call the `lazy.setup` function.")
log.help("Are you sure that this is a Neovim config setup with `lazy.nvim`?")
os.exit(1)
