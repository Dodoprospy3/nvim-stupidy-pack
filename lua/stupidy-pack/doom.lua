--[[
Launch the actual DOOM game from Neovim.

Uses the `doomretro` source port from the Arch `extra` repository. DOOM is
copyrighted software: this module never downloads game data and never assumes
you own it. You must provide a legitimate IWAD yourself (doom.wad, doom2.wad,
etc.), or a free one such as Freedoom (AUR package `freedoom`).

The game runs in a Neovim terminal buffer inside a vertical split. Dependencies
are checked before launch and Arch Linux install instructions are shown when
they are missing.

Controls inside the game behave exactly like a terminal running doomretro:
`<Esc>` reaches the game (opens the DOOM menu). To close from Neovim instead,
leave terminal mode with `<C-\><C-n>` and press `q` or `<Esc>` (or just quit
the game from its own menu).
--]]

local M = {}

local state = {
    win = nil,
    buf = nil,
    job = nil,
    running = false,
}

local ENGINE = "doomretro"

--- Filenames that are valid DOOM IWADs (must be provided by the user).
local IWAD_NAMES = {
    "doom.wad",
    "doom2.wad",
    "plutonia.wad",
    "tnt.wad",
    "freedoom.wad",
    "freedoom1.wad",
    "freedoom2.wad",
    "freedoom-phase1.wad",
    "freedoom-phase2.wad",
}

--- Locations searched for an IWAD.
local IWAD_DIRS = {
    function() return vim.fn.getcwd() end,
    function() return vim.fn.expand("~/") end,
    function() return vim.fn.expand("~/.local/share/doom/") end,
    function() return vim.fn.expand("~/Games/doom/") end,
    function() return "/usr/share/doom/" end,
    function() return "/usr/share/games/doom/" end,
}

function M.is_engine_installed()
    return vim.fn.executable(ENGINE) == 1
end

--- Find a DOOM IWAD, or nil. Searches cwd, home, ~/.local/share/doom and the
--- standard system data directories.
function M.find_iwad()
    local seen = {}
    for _, dir_fn in ipairs(IWAD_DIRS) do
        local ok, dir = pcall(dir_fn)
        if ok and type(dir) == "string" and dir ~= "" and not seen[dir] then
            seen[dir] = true
            if vim.fn.isdirectory(dir) == 1 then
                for _, name in ipairs(IWAD_NAMES) do
                    local path = dir .. "/" .. name
                    if vim.fn.filereadable(path) == 1 then
                        return path
                    end
                end
            end
        end
    end
    return nil
end

function M.is_running()
    return state.running
end

local function missing_engine_msg()
    return table.concat({
        "DOOM engine not found (" .. ENGINE .. ").",
        "",
        "Install it on Arch Linux:",
        "  sudo pacman -S " .. ENGINE,
    }, "\n")
end

local function missing_iwad_msg()
    return table.concat({
        "No DOOM IWAD found.",
        "",
        "This plugin never downloads game data. Provide a legitimate IWAD",
        "(doom.wad, doom2.wad, ...) yourself in one of these locations:",
        "  - current working directory",
        "  - ~/.local/share/doom/",
        "  - /usr/share/doom/",
        "",
        "No IWAD yet? Freedoom is a free, legal Doom-compatible IWAD:",
        "  yay -S freedoom        (or: paru -S freedoom)",
    }, "\n")
end

--- Open DOOM in a vertical terminal split (or refocus it if already running).
function M.open()
    if state.running then
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_set_current_win(state.win)
        end
        return
    end

    if not M.is_engine_installed() then
        vim.notify(missing_engine_msg(), vim.log.levels.ERROR, {
            title = "Stupidity Pack: DOOM",
        })
        return
    end

    local iwad = M.find_iwad()
    if not iwad then
        vim.notify(missing_iwad_msg(), vim.log.levels.ERROR, {
            title = "Stupidity Pack: DOOM",
        })
        return
    end

    -- Vertical split (existing 'splitright'/'splitbelow' options respected).
    local prev = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()

    state.win = win
    state.buf = buf
    state.prev_win = prev
    state.running = true

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "stupidy_doom"

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false
    vim.wo[win].wrap = false

    -- Close from normal mode with <Esc> or q (terminal mode is left with
    -- <C-\><C-n>; <Esc> in terminal mode goes to the game, like any terminal).
    vim.keymap.set("n", "<Esc>", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    vim.keymap.set("n", "q", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    -- `-iwad` selects the game data (confirmed: doomretro CLI parameter).
    local chan = vim.fn.termopen({ ENGINE, "-iwad", iwad }, {
        on_exit = function()
            vim.schedule(function()
                if state.running then
                    M.close()
                end
            end)
        end,
    })
    state.job = chan

    -- Game input: enter terminal mode.
    pcall(vim.cmd, "startinsert")

    -- Lifecycle: clean up when the split/buffer closes or on Neovim exit.
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed", "VimLeavePre" }, {
        group = vim.api.nvim_create_augroup("stupidy_doom_" .. tostring(buf), { clear = true }),
        callback = function(args)
            if args.event == "VimLeavePre" then
                M.close()
            elseif args.event == "WinClosed" then
                if tonumber(args.match) == state.win then
                    M.close()
                end
            elseif args.event == "BufWipeout" then
                if args.buf == state.buf then
                    M.close()
                end
            end
        end,
    })
end

--- Toggle: launch when closed, focus when running but unfocused, kill when focused.
function M.toggle()
    if not state.running then
        M.open()
        return
    end
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        if vim.api.nvim_get_current_win() == state.win then
            M.close()
        else
            vim.api.nvim_set_current_win(state.win)
        end
    end
end

function M.close()
    if not state.running then
        return
    end
    state.running = false

    if state.job then
        pcall(vim.fn.jobstop, state.job)
        state.job = nil
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        pcall(vim.api.nvim_win_close, state.win, true)
        state.win = nil
    end

    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
        state.buf = nil
    end

    if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
        pcall(vim.api.nvim_set_current_win, state.prev_win)
    end
    state.prev_win = nil
end

return M
