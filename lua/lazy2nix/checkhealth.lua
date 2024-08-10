local health = vim.health

local original_error_handler = health.error

local did_fail = false

---@diagnostic disable-next-line: duplicate-set-field
function health.error(msg, ...)
    did_fail = true
    original_error_handler(msg, ...)
end

health._check("", "*")

vim.cmd(":w !tee")

if did_fail then
    os.exit(1)
end
