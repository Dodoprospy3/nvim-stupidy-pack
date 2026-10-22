--[[
Spinning 3D ASCII donut rendered in a Neovim floating window.

The animation is driven by a libuv timer (`vim.uv`) so it never blocks the
Neovim event loop: you can keep editing normally while the donut spins.

Self-contained port of the classic "donut.c" by Andy Sloane:
https://www.a1k0n.net/2011/07/20/donut-math.html
--]]

local M = {}

local state = {
    buf = nil,
    win = nil,
    timer = nil,
    running = false,
    angle_a = 0,
    angle_b = 0,
    ex = 0,  -- cached max projected extent in x (see compute_extents)
    ey = 0,  -- cached max projected extent in y
}

-- Donut rendering constants.
local R1 = 1      -- radius of the tube cross-section
local R2 = 2      -- radius of the torus (center to tube center)
local K2 = 5      -- distance from viewer to donut
local K1 = 0      -- computed per frame from the screen width

local theta_spacing = 0.07
local phi_spacing = 0.02

local chars = ".,-~:;!#$@"   -- luminance ramp, darkest to brightest

-- Precompute the largest projected extent of the donut (max ooz*|x| and
-- ooz*|y|) for the current orientation. The torus is symmetric, so this is
-- essentially rotation-invariant; we compute it once and reuse it to scale
-- the projection so every part of the donut fits inside the window.
local function compute_extents()
    local maxx, maxy = 0, 0
    local a = state.angle_a
    local b = state.angle_b
    local sin_a, cos_a = math.sin(a), math.cos(a)
    local sin_b, cos_b = math.sin(b), math.cos(b)

    local theta = 0
    while theta < 2 * math.pi do
        local sin_theta, cos_theta = math.sin(theta), math.cos(theta)
        local phi = 0
        while phi < 2 * math.pi do
            local sin_phi, cos_phi = math.sin(phi), math.cos(phi)
            local circle_x = R2 + R1 * cos_theta
            local circle_y = R1 * sin_theta
            local x = circle_x * (cos_b * cos_phi + sin_a * sin_b * sin_phi)
                - circle_y * cos_a * sin_b
            local y = circle_x * (sin_b * cos_phi - sin_a * cos_b * sin_phi)
                + circle_y * cos_a * cos_b
            local z = K2 + cos_a * circle_x * sin_phi + circle_y * sin_a
            local ooz = 1 / z
            local ex = ooz * math.abs(x)
            local ey = ooz * math.abs(y)
            if ex > maxx then maxx = ex end
            if ey > maxy then maxy = ey end
            phi = phi + phi_spacing
        end
        theta = theta + theta_spacing
    end

    -- Guard against a degenerate result.
    if maxx <= 0 then maxx = 1 end
    if maxy <= 0 then maxy = 1 end
    return maxx, maxy
end

local function render()
    local win = state.win
    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end

    local width = vim.api.nvim_win_get_width(win)
    local height = vim.api.nvim_win_get_height(win)
    if width < 5 or height < 3 then
        return
    end

    -- Scale the projection so the whole donut fits inside the window:
    --   horizontal: K1 * ex        <= width  / 2
    --   vertical:   K1 * ey * 0.5  <= height / 2   (0.5 = tall-cell aspect)
    local ex, ey = state.ex, state.ey
    if ex <= 0 or ey <= 0 then
        ex, ey = compute_extents()
        state.ex, state.ey = ex, ey
    end
    local k1_w = (width * 0.5) / ex
    local k1_h = (height * 0.5) / (ey * 0.5)
    K1 = math.min(k1_w, k1_h)

    local output = {}
    local z_buffer = {}
    local output_chars = {}

    local size = width * height
    for i = 1, size do
        z_buffer[i] = 0
        output_chars[i] = " "
    end

    local a = state.angle_a
    local b = state.angle_b

    local sin_a = math.sin(a)
    local cos_a = math.cos(a)
    local sin_b = math.sin(b)
    local cos_b = math.cos(b)

    -- Iterate over the torus.
    local theta = 0
    while theta < 2 * math.pi do
        local sin_theta = math.sin(theta)
        local cos_theta = math.cos(theta)

        local phi = 0
        while phi < 2 * math.pi do
            local sin_phi = math.sin(phi)
            local cos_phi = math.cos(phi)

            -- 3D coordinates of a point on the torus surface before rotation.
            local circle_x = R2 + R1 * cos_theta
            local circle_y = R1 * sin_theta

            -- Rotate around the X axis (a) then the Z axis (b).
            local x = circle_x * (cos_b * cos_phi + sin_a * sin_b * sin_phi)
                - circle_y * cos_a * sin_b
            local y = circle_x * (sin_b * cos_phi - sin_a * cos_b * sin_phi)
                + circle_y * cos_a * cos_b
            local z = K2 + cos_a * circle_x * sin_phi + circle_y * sin_a
            local ooz = 1 / z  -- "one over z" for depth

            -- Project to 2D.
            local xp = math.floor(width / 2 + K1 * ooz * x)
            -- 0.5 compensates for tall terminal cells.
            local yp = math.floor(height / 2 - K1 * ooz * y * 0.5)

            -- Lighting: luminance from the surface normal.
            local l = cos_phi * cos_theta * sin_b
                - cos_a * cos_theta * sin_phi
                - sin_a * sin_theta
                + cos_b * (cos_a * sin_theta - cos_theta * sin_a * sin_phi)

            if xp >= 0 and xp < width and yp >= 0 and yp < height then
                local idx = yp * width + xp + 1  -- Lua is 1-indexed
                if ooz > z_buffer[idx] then
                    z_buffer[idx] = ooz
                    local luminance = math.floor(l * 8)
                    if luminance < 0 then
                        luminance = 0
                    end
                    if luminance > #chars then
                        luminance = #chars
                    end
                    output_chars[idx] = chars:sub(luminance + 1, luminance + 1)
                end
            end

            phi = phi + phi_spacing
        end

        theta = theta + theta_spacing
    end

    -- Build the lines.
    for y = 0, height - 1 do
        local line = {}
        for x = 0, width - 1 do
            line[#line + 1] = output_chars[y * width + x + 1]
        end
        output[#output + 1] = table.concat(line)
    end

    local ok = pcall(function()
        -- The buffer is non-modifiable to keep it scratch-like; toggle to write.
        vim.bo[state.buf].modifiable = true
        vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, output)
        vim.bo[state.buf].modifiable = false
    end)
    if not ok then
        return  -- the buffer may have been deleted mid-frame
    end

    -- Advance the rotation angles.
    state.angle_a = a + 0.04
    state.angle_b = b + 0.02
end

local function float_opts()
    local avail_w = vim.o.columns
    local avail_h = vim.o.lines - (vim.o.cmdheight or 0)

    local box_w = math.max(math.min(math.floor(avail_w * 0.85), avail_w), math.min(50, avail_w), 5)
    local box_h = math.max(math.min(math.floor(avail_h * 0.85), avail_h), math.min(20, avail_h), 4)

    return {
        relative = "editor",
        width = box_w,
        height = box_h,
        row = math.floor((avail_h - box_h) / 2),
        col = math.floor((avail_w - box_w) / 2),
        style = "minimal",
        border = "none",
        focusable = true,
    }
end

function M.is_running()
    return state.running
end

--- Open the donut (or refocus it if it is already open).
function M.open()
    if state.running then
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_set_current_win(state.win)
        end
        return
    end

    local prev = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, float_opts())

    state.buf = buf
    state.win = win
    state.prev_win = prev
    state.running = true

    -- Measure the donut's projected extent once so render() can scale it to
    -- always fit fully inside the window (nothing clipped).
    state.ex, state.ey = compute_extents()

    -- Scratch buffer: never prompts to save, wiped when closed.
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "stupidy_donut"

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false
    vim.wo[win].wrap = false
    -- Transparent float background: use Normal (which the theme sets to a
    -- transparent bg) instead of NormalFloat's opaque background.
    vim.wo[win].winhighlight = "Normal:Normal"
    -- Actually see-through: without winblend the float's (space) cells mask
    -- the buffer text behind them even with a transparent bg. winblend lets
    -- empty cells reveal the text underneath while the donut glyphs stay
    -- fully drawn on top.
    vim.wo[win].winblend = 100

    -- Close from normal mode with <Esc> or q.
    vim.keymap.set("n", "<Esc>", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    vim.keymap.set("n", "q", function()
        M.close()
    end, { buffer = buf, silent = true, nowait = true })

    -- Animation timer (~30 FPS) on the libuv event loop: never blocks editing.
    local timer = vim.uv.new_timer()
    state.timer = timer
    timer:start(
        0,
        33,
        vim.schedule_wrap(function()
            if not state.running then
                return
            end
            local ok, err = pcall(render)
            if not ok then
                vim.schedule(function()
                    M.close()
                    vim.notify("Donut stopped: " .. tostring(err), vim.log.levels.WARN)
                end)
            end
        end)
    )

    render()

    -- Lifecycle: clean up on any window/buffer close (ours only), on exit,
    -- and keep the float centered when the terminal is resized.
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed", "VimLeavePre", "VimResized" }, {
        group = vim.api.nvim_create_augroup("stupidy_donut_" .. tostring(buf), { clear = true }),
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

    if state.timer then
        pcall(function()
            state.timer:stop()
            state.timer:close()
        end)
        state.timer = nil
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
