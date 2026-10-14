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

# =====================================================================
# BEHAVIOR & QUALITY OF LIFE
# =====================================================================

# Session
c.auto_save.session = True
c.session.lazy_restore = True

# Tabs
c.tabs.background = True
c.tabs.last_close = "startpage"
c.tabs.mousewheel_switching = False
c.tabs.padding = {"top": 8, "bottom": 8, "left": 12, "right": 12}
c.tabs.favicons.show = "always"
c.tabs.title.format = "{audio}{current_title}"
c.tabs.indicator.width = 2

# Search
c.search.ignore_case = "smart"
c.search.wrap = True

# Scrolling
c.scrolling.smooth = True
c.scrolling.bar = "when-searching"

# Downloads
c.downloads.location.directory = "~/Downloads"
c.downloads.location.prompt = False
c.downloads.location.remember = True
c.downloads.open_dispatcher = ""

# Editor (for textarea editing)
c.editor.command = ["kitty", "-e", "nvim", "{file}"]

# Spell check
c.spellcheck.languages = ["en-US", "pt-PT"]

# Start page
c.url.start_pages = ["about:blank"]
c.url.default_page = "about:blank"

# Private browsing
c.content.private_browsing = False

# =====================================================================
# KEYBINDINGS (vim-style)
# =====================================================================

# Unbind defaults we'll override
config.unbind("d")      # close tab
config.unbind("gt")     # next tab

config.unbind("J")      # next tab
config.unbind("K")      # prev tab
config.unbind("<Ctrl-Tab>")  # next tab
config.unbind("<Ctrl-Shift-Tab>")  # prev tab

# --- Navigation ---
config.bind("h", "scroll left")
config.bind("j", "scroll down")
config.bind("k", "scroll up")
config.bind("l", "scroll right")
config.bind("H", "back")
config.bind("L", "forward")
config.bind("gg", "scroll-page 0 0")
config.bind("G", "scroll-page 0 100%")
config.bind("gt", "tab-next")
config.bind("gT", "tab-prev")
config.bind("gn", "tab-next")
config.bind("gp", "tab-prev")
config.bind("<Ctrl-Tab>", "tab-next")
config.bind("<Ctrl-Shift-Tab>", "tab-prev")

# --- Tab management ---
config.bind("t", "open -t")           # new tab
config.bind("T", "open -t -b")        # new tab background
config.bind("d", "tab-close")         # close tab
config.bind("u", "undo")              # reopen closed tab
config.bind("g0", "tab-first")
config.bind("g$", "tab-last")
config.bind("<Ctrl-1>", "tab-focus 1")
config.bind("<Ctrl-2>", "tab-focus 2")
config.bind("<Ctrl-3>", "tab-focus 3")
config.bind("<Ctrl-4>", "tab-focus 4")
config.bind("<Ctrl-5>", "tab-focus 5")
config.bind("<Ctrl-6>", "tab-focus 6")
config.bind("<Ctrl-7>", "tab-focus 7")
config.bind("<Ctrl-8>", "tab-focus 8")
config.bind("<Ctrl-9>", "tab-focus 9")
config.bind("<Ctrl-0>", "tab-focus -1")
config.bind("gl", "tab-move +")
config.bind("gh", "tab-move -")
config.bind("g<", "tab-move 0")
config.bind("g>", "tab-move -1")

# --- Search ---
config.bind("/", "set-cmd-text /")
config.bind("?", "set-cmd-text ?")
config.bind("n", "search-next")
config.bind("N", "search-prev")
config.bind("<Ctrl-n>", "search-next")
config.bind("<Ctrl-p>", "search-prev")

# --- Hints ---
config.bind("f", "hint")
config.bind("F", "hint --tab")
config.bind(";f", "hint --tab-bg")
config.bind(";F", "hint --tab-bg --rapid")
config.bind(";i", "hint images")
config.bind(";y", "hint links yank")

# --- Modes ---
config.bind("v", "enter-mode caret")
config.bind("V", "enter-mode caret --select")
config.bind("<Escape>", "leave-mode")
config.bind("<Ctrl-c>", "leave-mode")

# --- Commands ---
config.bind(":", "set-cmd-text :")
config.bind(";", "set-cmd-text :")
config.bind("<Space>", "set-cmd-text :")

# --- Open links ---
config.bind("o", "set-cmd-text -s :open")
config.bind("O", "set-cmd-text -s :open -t")
config.bind(";o", "set-cmd-text -s :open -p")
config.bind(";O", "set-cmd-text -s :open -w")

# --- Zoom ---
config.bind("zi", "zoom-in")
config.bind("zo", "zoom-out")
config.bind("z0", "zoom 100")

# --- Reload ---
config.bind("r", "reload")
config.bind("R", "reload -f")

# --- Yank / clipboard ---
config.bind("yy", "yank url")
config.bind(";y", "hint links yank")
config.bind(";Y", "hint links yank-primary")
config.bind("p", "open -- {clipboard}")
config.bind("P", "open -t -- {clipboard}")

# --- History / bookmarks ---
config.bind("<Ctrl-h>", "history")
config.bind("b", "set-cmd-text -s :bookmark-add")
config.bind("B", "set-cmd-text -s :bookmark-load")

# --- Developer tools ---
config.bind("<F12>", "devtools")
config.bind("<Ctrl-Shift-i>", "devtools")

# --- Misc ---
config.bind("<Ctrl-l>", "fake-key <Ctrl-l>")  # clear messages
config.bind("xx", "restart")
config.bind("xq", "quit")
config.bind("<Ctrl-q>", "quit")

# =====================================================================
# PRIVACY & SECURITY
# =====================================================================

# Adblock (built-in)
c.content.blocking.enabled = True
c.content.blocking.method = "both"  # adblock + host blocking
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt",
]

# Cookies
c.content.cookies.accept = "no-3rdparty"
c.content.cookies.store = True

# Referrer
c.content.headers.referer = "same-domain"

# Canvas fingerprinting
c.content.canvas_reading = False

# WebRTC (prevent IP leak)
c.content.webrtc_ip_handling_policy = "default-public-interface-only"



# Notifications
c.content.notifications.enabled = False

# Geolocation
c.content.geolocation = False

# =====================================================================
# EXTRA SETTINGS
# =====================================================================

# PDF viewer (external)
c.content.pdfjs = True

# User agent (optional: less fingerprinting)
# c.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# Host blocking (supplement to adblock) - uses content.blocking.enabled
c.content.blocking.hosts.lists = [
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
]
c.content.blocking.hosts.block_subdomains = True

# Completion
c.completion.use_best_match = True
c.completion.shrink = True
c.completion.timestamp_format = "%Y-%m-%d %H:%M"

# Messages
c.messages.timeout = 3000

# Input
c.input.insert_mode.auto_load = True
c.input.insert_mode.auto_leave = True
c.input.insert_mode.plugins = True

# Window
c.window.hide_decoration = True
c.window.title_format = "{current_title} - qutebrowser"

# =====================================================================
# ALIASES
# =====================================================================

c.aliases = {
    "w": "session-save",
    "wq": "session-save ;; quit",
    "qa": "quit",
    "o": "open",
    "ot": "open -t",
    "ob": "open -b",
    "obt": "open -t -b",
}