-- nvim-stupidy-pack: register :Stupidy* commands at startup.
-- Keymaps are only created by require("stupidy-pack").setup().

if vim.g.loaded_stupidy_pack then
    return
end
vim.g.loaded_stupidy_pack = true

pcall(function()
    require("stupidy-pack").register_commands()
end)
