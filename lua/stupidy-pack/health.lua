-- :checkhealth stupidy-pack

local M = {}

function M.check()
    vim.health.start("stupidy-pack: core")
    vim.health.ok("Lua modules load (require('stupidy-pack'))")
    local has_uv = vim.uv ~= nil or vim.loop ~= nil
    if has_uv then
        vim.health.ok("libuv timer API available (donut animation)")
    else
        vim.health.error("vim.uv/vim.loop missing — Neovim too old (need 0.10+)")
    end

    vim.health.start("stupidy-pack: aquarium (asciiquarium)")
    if vim.fn.executable("asciiquarium") == 1 then
        vim.health.ok("asciiquarium found: " .. vim.fn.exepath("asciiquarium"))
    else
        vim.health.warn("asciiquarium not found. Arch Linux: sudo pacman -S asciiquarium")
    end

    vim.health.start("stupidy-pack: DOOM (doomretro)")
    local doom = require("stupidy-pack.doom")
    if doom.is_engine_installed() then
        vim.health.ok("doomretro found: " .. vim.fn.exepath("doomretro"))
    else
        vim.health.warn("doomretro not found. Arch Linux: sudo pacman -S doomretro")
    end

    local iwad = doom.find_iwad()
    if iwad then
        vim.health.ok("IWAD found: " .. iwad)
    else
        vim.health.warn(
            "No DOOM IWAD found. Provide one yourself (doom.wad, doom2.wad) in "
                .. "cwd or ~/.local/share/doom/. Free/legal option: yay -S freedoom",
            { "This plugin never downloads game data." }
        )
    end
end

return M
