# Everforest Green Dark Dim for qutebrowser
#
# Mirrors ~/dotfiles/everforest-green-dark-dim.md ramp:
#   bg #1e2326 / base #232a2e / hover #2e383c / border #3a4141
#   fg #ffffff / green #a7c080 / red #e67e80
# Green-accent-only chrome (matches opencode/rofi/Zed); red kept for
# errors/urgent, yellow for warnings.
# Websites are left alone (darkmode inversion OFF); only
# preferred_color_scheme is set to dark so sites with native
# prefers-color-scheme support render dark on their own.

config.load_autoconfig(True)

# --- palette ---
bg0 = "#1e2326"      # main background
bg1 = "#232a2e"      # inputs / panels / base
bg2 = "#272e33"
hover = "#2e383c"
border = "#3a4141"
fg = "#ffffff"
muted = "#7a8478"
grey1 = "#859289"
green = "#a7c080"
red = "#e67e80"
yellow = "#dbbc7f"
blue = "#7fbbb3"
purple = "#d699b6"
aqua = "#83c092"
orange = "#e69875"

# --- fonts (match setup: GeistMono Nerd Font Mono) ---
font = "11pt GeistMono Nerd Font Mono"
c.fonts.default_family = "GeistMono Nerd Font Mono"
c.fonts.completion.entry = font
c.fonts.completion.category = f"bold {font}"
c.fonts.statusbar = font
c.fonts.tabs.selected = font
c.fonts.tabs.unselected = font
c.fonts.hints = f"bold 11pt GeistMono Nerd Font Mono"
c.fonts.downloads = font
c.fonts.prompts = font
c.fonts.contextmenu = font
c.fonts.tooltip = font
c.fonts.keyhint = font
c.fonts.messages.info = font
c.fonts.messages.warning = font
c.fonts.messages.error = font

# --- completion ---
c.colors.completion.category.bg = bg0
c.colors.completion.category.border.top = border
c.colors.completion.category.border.bottom = border
c.colors.completion.category.fg = green
c.colors.completion.even.bg = bg1
c.colors.completion.odd.bg = bg1
c.colors.completion.fg = fg
c.colors.completion.item.selected.bg = green
c.colors.completion.item.selected.fg = bg0
c.colors.completion.item.selected.border.top = green
c.colors.completion.item.selected.border.bottom = green
c.colors.completion.item.selected.match.fg = bg0
c.colors.completion.match.fg = orange
c.colors.completion.scrollbar.bg = bg0
c.colors.completion.scrollbar.fg = hover

# --- context menu ---
c.colors.contextmenu.menu.bg = bg1
c.colors.contextmenu.menu.fg = fg
c.colors.contextmenu.disabled.bg = bg1
c.colors.contextmenu.disabled.fg = muted
c.colors.contextmenu.selected.bg = green
c.colors.contextmenu.selected.fg = bg0

# --- downloads ---
c.colors.downloads.bar.bg = bg0
c.colors.downloads.start.bg = blue
c.colors.downloads.start.fg = bg0
c.colors.downloads.stop.bg = green
c.colors.downloads.stop.fg = bg0
c.colors.downloads.error.bg = red
c.colors.downloads.error.fg = bg0
c.colors.downloads.system.bg = "rgb"
c.colors.downloads.system.fg = "rgb"

# --- hints ---
c.colors.hints.bg = green
c.colors.hints.fg = bg0
c.colors.hints.match.fg = blue

# --- keyhint ---
c.colors.keyhint.bg = "rgba(30, 35, 38, 90%)"
c.colors.keyhint.fg = fg
c.colors.keyhint.suffix.fg = green

# --- messages ---
c.colors.messages.error.bg = red
c.colors.messages.error.fg = bg0
c.colors.messages.error.border = red
c.colors.messages.warning.bg = yellow
c.colors.messages.warning.fg = bg0
c.colors.messages.warning.border = yellow
c.colors.messages.info.bg = bg0
c.colors.messages.info.fg = fg
c.colors.messages.info.border = border

# --- prompts ---
c.colors.prompts.bg = bg1
c.colors.prompts.fg = fg
c.colors.prompts.border = border
c.colors.prompts.selected.bg = green
c.colors.prompts.selected.fg = bg0

# --- statusbar ---
c.colors.statusbar.normal.bg = bg0
c.colors.statusbar.normal.fg = fg
c.colors.statusbar.insert.bg = green
c.colors.statusbar.insert.fg = bg0
c.colors.statusbar.passthrough.bg = blue
c.colors.statusbar.passthrough.fg = bg0
c.colors.statusbar.private.bg = bg1
c.colors.statusbar.private.fg = fg
c.colors.statusbar.command.bg = bg1
c.colors.statusbar.command.fg = fg
c.colors.statusbar.command.private.bg = bg1
c.colors.statusbar.command.private.fg = fg
c.colors.statusbar.caret.bg = purple
c.colors.statusbar.caret.fg = bg0
c.colors.statusbar.caret.selection.bg = purple
c.colors.statusbar.caret.selection.fg = bg0
c.colors.statusbar.progress.bg = green
c.colors.statusbar.url.fg = fg
c.colors.statusbar.url.hover.fg = aqua
c.colors.statusbar.url.success.http.fg = fg
c.colors.statusbar.url.success.https.fg = green
c.colors.statusbar.url.warn.fg = yellow
c.colors.statusbar.url.error.fg = red

# --- tabs ---
c.colors.tabs.bar.bg = bg0
c.colors.tabs.odd.bg = bg0
c.colors.tabs.odd.fg = muted
c.colors.tabs.even.bg = bg0
c.colors.tabs.even.fg = muted
c.colors.tabs.selected.odd.bg = bg1
c.colors.tabs.selected.odd.fg = fg
c.colors.tabs.selected.even.bg = bg1
c.colors.tabs.selected.even.fg = fg
c.colors.tabs.pinned.odd.bg = bg0
c.colors.tabs.pinned.odd.fg = muted
c.colors.tabs.pinned.even.bg = bg0
c.colors.tabs.pinned.even.fg = muted
c.colors.tabs.pinned.selected.odd.bg = bg1
c.colors.tabs.pinned.selected.odd.fg = fg
c.colors.tabs.pinned.selected.even.bg = bg1
c.colors.tabs.pinned.selected.even.fg = fg
c.colors.tabs.indicator.start = green
c.colors.tabs.indicator.stop = green
c.colors.tabs.indicator.error = red
c.colors.tabs.indicator.system = "rgb"

# --- tooltip ---
c.colors.tooltip.bg = bg1
c.colors.tooltip.fg = fg

# --- webpage: leave sites alone, just advertise dark preference ---
c.colors.webpage.bg = bg0
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.enabled = False

# --- layout ---
c.tabs.position = "top"
c.tabs.show = "multiple"
c.statusbar.show = "always"
