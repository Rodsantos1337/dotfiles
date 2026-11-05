-- VSCode-style insert mode navigation.
-- Ctrl/Alt keys jump by lines and words without leaving insert mode.

return {
  -- Use <C-o> to run a normal-mode command while staying in insert mode.
  -- This lets you navigate like VSCode: Ctrl = screen lines, Alt/Meta = words.
  config = function()
    local i = vim.keymap.set

    -- Screen-line jumps (Ctrl+Up/Down) — matches VSCode behavior
    i("i", "<C-Up>",    "<C-o>gk",   { desc = "Insert mode: Ctrl+Up = screen line up" })
    i("i", "<C-Down>",  "<C-o>gj",   { desc = "Insert mode: Ctrl+Down = screen line down" })

    -- Word jumps (Alt/Meta + Left/Right) — matches VSCode behavior
    i("i", "<M-Up>",    "<C-o>b",    { desc = "Insert mode: Alt+Up = word back" })
    i("i", "<M-Down>",  "<C-o>w",    { desc = "Insert mode: Alt+Down = word forward" })

    -- Fallback: Ctrl+Left/Right also does word jumps (some terminals send M- as C-)
    i("i", "<C-Left>",  "<C-o>b",    { desc = "Insert mode: Ctrl+Left = word back" })
    i("i", "<C-Right>", "<C-o>w",    { desc = "Insert mode: Ctrl+Right = word forward" })

    -- Home / End of line
    i("i", "<Home>",    "<C-o>0",    { desc = "Insert mode: Home = start of line" })
    i("i", "<End>",     "<C-o>$",    { desc = "Insert mode: End = end of line" })

    -- Page up / down
    i("i", "<PageUp>",  "<C-o>b",    { desc = "Insert mode: PageUp = word back" })
    i("i", "<PageDown>", "<C-o>w",   { desc = "Insert mode: PageDn = word forward" })

    -- Arrow keys stay as-is (they already work in insert mode)
  end,
}
