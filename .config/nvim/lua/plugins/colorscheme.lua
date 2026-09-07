-- Everforest colorscheme to match rod's desktop theme (i3/GTK/polybar).
-- Adding the plugin + telling LazyVim to use it is all that's needed;
-- tweak variants via g:everforest_background ("hard"/"medium"/"soft") if desired.
return {
  { "sainnhe/everforest", lazy = false, priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
