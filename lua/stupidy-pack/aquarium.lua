--[[
Animated ASCII aquarium in a Neovim floating window.

Wraps the `asciiquarium` system program rather than reinventing it. Checks that
it is installed before launching, tells you how to install it on Arch Linux if
it is missing, and terminates the process cleanly when the window closes or
Neovim exits.

The window opens in normal mode (asciiquarium does not take input), so `q`
or `<Esc>` closes it immediately.
--]]

local M = {}

local state = {
    buf = nil,
    win = nil,
    job = nil,
    running = false,
}

local PROGRAM = "asciiquarium"

local function is_installed()
    return vim.fn.executable(PROGRAM) == 1
end

local function float_opts()
    local avail_w = vim.o.columns
    local avail_h = vim.o.lines - (vim.o.cmdheight or 0)

    local box_w = math.max(math.min(math.floor(avail_w * 0.9), avail_w), math.min(60, avail_w), 5)
    local box_h = math.max(math.min(math.floor(avail_h * 0.9), avail_h), math.min(25, avail_h), 4)

    return {
        relative = "editor",
        width = box_w,
        height = box_h,
        row = math.floor((avail_h - box_h) / 2),
        col = math.floor((avail_w - box_w) / 2),
        style = "minimal",
        border = "rounded",
        focusable = true,
    }
end

local function stop_job()
    if not state.job then
        return
    end
    -- SIGTERM first; fall back to Ctrl-C for builds that ignore it.
    pcall(vim.fn.jobstop, state.job)
    local job = state.job
    vim.defer_fn(function()
        pcall(function()
            if vim.fn.jobwait({ job }, 0)[1] == -1 then
                vim.fn.jobsend(job, "\003")
            end
        end)
    end, 500)
    state.job = nil
end

function M.is_installed()
    return is_installed()
end

function M.is_running()
    return state.running
end

--- Open the aquarium (or refocus it if it is already open).
function M.open()
    if state.running then
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_set_current_win(state.win)
        end
        return
    end

    if not is_installed() then
        vim.notify(
            table.concat({
                "asciiquarium is not installed.",
                "",
                "Install it on Arch Linux:",
                "  sudo pacman -S asciiquarium",
            }, "\n"),
            vim.log.levels.ERROR,
            { title = "Stupidity Pack: Aquarium" }
        )
        return
    end

    local prev = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, float_opts())

    state.buf = buf
    state.win = win
    state.prev_win = prev
    state.running = true

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "stupidy_aquarium"

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false
    vim.wo[win].wrap = false

    -- Close from normal mode with <Esc> or q.
    vim.keymap.set("n", "<Esc>", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    vim.keymap.set("n", "q", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    -- Launch asciiquarium in this buffer's terminal.
    local chan = vim.fn.termopen(PROGRAM, {
        on_exit = function()
            vim.schedule(function()
                if state.running then
                    M.close()
                end
            end)
        end,
    })
    state.job = chan

    -- asciiquarium takes no input: stay in normal mode so q/<Esc> close it
    -- instantly (termopen may have switched us into terminal mode).
    pcall(vim.cmd, "stopinsert")

    -- Lifecycle: clean up on our window/buffer closing or on Neovim exit;
    -- keep the float centered when the terminal is resized.
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed", "VimLeavePre", "VimResized" }, {
        group = vim.api.nvim_create_augroup("stupidy_aquarium_" .. tostring(buf), { clear = true }),
        callback = function(args)
            if args.event == "VimResized" then
                if state.win and vim.api.nvim_win_is_valid(state.win) then
                    pcall(vim.api.nvim_win_set_config, state.win, float_opts())
                end
            elseif args.event == "VimLeavePre" then
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

--- Toggle: open when closed, focus when open but unfocused, close when focused.
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

    stop_job()

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
