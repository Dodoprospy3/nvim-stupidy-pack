--[[
nvim-stupidy-pack: three ridiculous features for Neovim.

  - stupidity.donut    : spinning 3D ASCII donut in a floating window
  - stupidity.aquarium : animated ASCII aquarium (asciiquarium) in a float
  - stupidity.doom     : real DOOM (doomretro) in a terminal split

Usage:

    require("stupidy-pack").setup()

setup() registers default keymaps and user commands. The :Stupidy* commands
are also registered by plugin/stupidy-pack.lua even without setup().
--]]

local M = {}

local defaults = {
    -- Default keymaps. Set the whole table to false to disable all of them,
    -- or override individual entries (set one to false to skip it).
    keymaps = {
        donut = "<leader>sd",
        aquarium = "<leader>sa",
        doom = "<leader>sD",
    },
    -- Register :StupidyDonut, :StupidyAquarium, :StupidyDoom.
    commands = true,
}

local opts = vim.deepcopy(defaults)

local features = { "donut", "aquarium", "doom" }

local command_names = {
    donut = "StupidyDonut",
    aquarium = "StupidyAquarium",
    doom = "StupidyDoom",
}

local descriptions = {
    donut = "Stupidy: toggle the spinning 3D ASCII donut",
    aquarium = "Stupidy: toggle the ASCII aquarium",
    doom = "Stupidy: launch DOOM (doomretro)",
}

-- Feature modules are required lazily so that merely loading this module
-- (e.g. from plugin/) stays cheap; they have no startup side effects.
local cache = {}
local function feature(name)
    if not cache[name] then
        cache[name] = require("stupidy-pack." .. name)
    end
    return cache[name]
end

--- Public access: require("stupidy-pack").donut.open() etc.
function M.feature(name)
    return feature(name)
end

--- Validate and run an action (toggle/open/close) on a feature.
local function run(name, action)
    local mod = feature(name)
    action = (action and action ~= "") and action or "toggle"
    local fn = mod[action]
    if type(fn) ~= "function" then
        vim.notify(
            ("Stupidy: unknown action %q (use toggle, open or close)"):format(action),
            vim.log.levels.WARN,
            { title = "Stupidity Pack" }
        )
        return
    end
    fn()
end

--- Register the :Stupidy* user commands (idempotent).
function M.register_commands()
    for _, name in ipairs(features) do
        vim.api.nvim_create_user_command(command_names[name], function(cmd)
            if cmd.args ~= "" and not ({ toggle = true, open = true, close = true })[cmd.args] then
                vim.notify(
                    ("Stupidy: unknown action %q (use toggle, open or close)"):format(cmd.args),
                    vim.log.levels.WARN,
                    { title = "Stupidity Pack" }
                )
                return
            end
            run(name, cmd.args)
        end, {
            nargs = "?",
            desc = descriptions[name],
        })
    end
end

local function remove_commands()
    for _, name in pairs(command_names) do
        pcall(vim.api.nvim_del_user_command, name)
    end
end

local function apply_keymaps()
    local keymaps = opts.keymaps
    if type(keymaps) ~= "table" then
        return
    end
    for _, name in ipairs(features) do
        local lhs = keymaps[name]
        if type(lhs) == "string" and lhs ~= "" then
            vim.keymap.set("n", lhs, function()
                run(name, "toggle")
            end, {
                desc = descriptions[name],
                silent = true,
            })
        end
    end
end

--- Setup the plugin. Safe to call multiple times.
--- @param user_opts table|nil see defaults above
function M.setup(user_opts)
    opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_opts or {})

    if opts.commands == false then
        remove_commands()
    else
        M.register_commands()
    end

    apply_keymaps()
    return M
end

-- Convenience accessors: require("stupidy-pack").donut / .aquarium / .doom
setmetatable(M, {
    __index = function(_, key)
        if (vim.tbl_contains(features, key)) then
            return feature(key)
        end
        return nil
    end,
})

return M
