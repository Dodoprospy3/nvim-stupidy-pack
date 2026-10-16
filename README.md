# nvim-stupidy-pack

Three absolutely ridiculous features for Neovim. Fully non-blocking, zero
plugins required, Lua-only integration.

```
                    @@@@@@$$$$#########$$##$$$$@@@@
                  @@@@@$$######!!!!!!!!!!#####$$$@@@@@@
                @@@@@$$$$##!!!;;::::::::;;;;!####$$$@@@@@@@$
               $@@@$$####!;;;::~~--------~~:;!!!!#$$$@@@@@@@@$
             #$@@@$$$$#!!;:::~-,,.......,,-~::;;!##$$$@@@@@@@@$
             $$$$$$$$##!;::~-,............,,~~:;!!##$$$@@@@@@@$$
            #$$$$$$$##!!;:~-,...............,-~:;!###$$$@@@@@@$$!
            !$$$$$$$$$#!!;:~-....         ....-~:;!!##$$$@@@@@$$$#
            #$$$$$$$$$##!;;~-..             ..-~:;!!#$$$$$$@@$$$$#
            !#$$@@@@$$$##!;:~.               .~:;!!##$$$$$$$$$$$$#;
            !#$$@@@@@@@$$#!!:~               -:;!###$$$$$$$$$$$$##;
            !#$$$@@@@@@@@$$$#;-             ~;!!##$$$$$$$$$$$$$###;
            !#$$@@@@@@@@@@@@@$#;           ;!##$$$$$$$$$$$$$$$##!!
            ;!#$$@@@@@@$$      ##$$$$$@@@@@@@@$$$$$$##!!;
            ~!##$$@@@@@@@@@@@@@@@@@@@@@@@$$$$$#$##!;:
             :!##$$@@@@@@@@@@@$$$$$$##!!;:
              ;!##$$@@@@@@@@@@$$$$$#$##!!;:
              .:;!##$$@@@@@@@@@@@$$$$###!!!:~
                :!###$$$@@@@@@@@@@@$$$$$###!!!;:~
                 ~:;!!###$$$$@@@@@@@@@@@@@@@$$$$######!!;;:~-
```

## Features

| Feature | What it is | Where it runs |
|---------|------------|---------------|
| 🍩 **Donut** | Continuously spinning 3D ASCII donut, rendered by a pure-Lua torus projection on a libuv timer (never blocks editing) | Floating window |
| 🐠 **Aquarium** | Animated ASCII aquarium via the system [`asciiquarium`](https://robobunny.com/projects/asciiquarium/html) program | Floating window |
| 💀 **DOOM** | The actual DOOM game via the [`doomretro`](https://doomretro.com) source port | Vertical terminal split |

All three clean up their processes and timers when their window closes, when
their buffer is wiped, and when Neovim exits.

## Requirements

- Neovim **0.10+** (tested on 0.12.6)
- Lua modules only — no other Neovim plugins required
- Optional system programs for two of the features (see [Dependencies](#dependencies))

## Installation

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
  "Dodoprospy3/nvim-stupidy-pack",
  config = function()
    require("stupidy-pack").setup()
  end,
}
```

**Native (no plugin manager)**

```sh
git clone https://github.com/Dodoprospy3/nvim-stupidy-pack.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/nvim-stupidy-pack"
```

```lua
-- init.lua
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-stupidy-pack")
require("stupidy-pack").setup()
```

## Default keymaps

| Keys | Action |
|------|--------|
| `<leader>sd` | Toggle the spinning donut |
| `<leader>sa` | Toggle the aquarium |
| `<leader>sD` | Launch DOOM |

`<leader>` is `<Space>` by default (set `vim.g.mapleader` before your plugin
manager loads, as usual).

While a window is focused: **`q` or `<Esc>` closes it** (for DOOM: leave
terminal mode with `<C-\><C-n>` first — plain `<Esc>` goes to the game, like
in any terminal).

Pressing the keybinding again while focused closes the feature; pressing it
while editing elsewhere focuses the feature's window.

## Configuration

`setup()` is optional for keymaps but recommended; `:Stupidy*` commands are
registered automatically by `plugin/`.

```lua
require("stupidy-pack").setup({
  -- Keymaps: set to false to disable all, override per feature,
  -- or set a single entry to false to skip it.
  keymaps = {
    donut = "<leader>sd",
    aquarium = "<leader>sa",
    doom = "<leader>sD",
  },
  -- Create the :Stupidy* user commands (set false to remove them).
  commands = true,
})
```

## Commands

| Command | Action |
|---------|--------|
| `:StupidyDonut [toggle\|open\|close]` | Spinning donut (defaults to `toggle`) |
| `:StupidyAquarium [toggle\|open\|close]` | ASCII aquarium |
| `:StupidyDoom [toggle\|open\|close]` | DOOM |
| `:checkhealth stupidy-pack` | Dependency report + install hints |

Lua API:

```lua
local stupidy = require("stupidy-pack")
stupidy.donut.open()      -- or stupidy.feature("donut").open()
stupidy.aquarium.toggle()
stupidy.doom.close()
```

## Dependencies

The donut needs nothing — it's pure Lua. The other two use system programs:

**Arch Linux:**

```sh
# 🐠 Aquarium
sudo pacman -S asciiquarium        # extra repo (pulls in perl-term-animation)

# 💀 DOOM engine
sudo pacman -S doomretro           # extra repo

# DOOM game data (IWAD) — you must provide this yourself.
# This plugin NEVER downloads game data. See below.
```

**DOOM IWAD (required, legal note):** DOOM's game data is copyrighted. This
plugin only *detects* an IWAD you already legitimately own and passes it with
`doomretro -iwad <file>`. It searches:

1. current working directory
2. `~/`
3. `~/.local/share/doom/`
4. `~/Games/doom/`
5. `/usr/share/doom/` and `/usr/share/games/doom/`

Recognized IWAD names: `doom.wad`, `doom2.wad`, `plutonia.wad`, `tnt.wad`,
`freedoom*.wad`.

- Own DOOM already? Copy your `doom.wad`/`doom2.wad` into one of those paths.
- Want a **100% free and legal** Doom-compatible IWAD?
  [Freedoom](https://freedoom.github.io/) is in the AUR:
  ```sh
  yay -S freedoom      # or: paru -S freedoom
  ```

Other distros: install `asciiquarium` and `doomretro` from your package
repositories (or build [doomretro](https://github.com/bradharding/doomretro)
from source) and place an IWAD where the search paths above can find it.

## Health check

```
:checkhealth stupidy-pack
```

Reports whether `asciiquarium`/`doomretro` are installed and whether a DOOM
IWAD was found, with exact Arch install commands for anything missing.

## License

[MIT](LICENSE)
