-- spell: spell checking for prose files, backed by the aspell binary.
--
-- aspell is spoken to over its ispell-compatible pipe protocol: the text is
-- written to stdin, one buffer line per `^`-prefixed data line, and aspell
-- answers with one result block per input line terminated by a blank line.
-- Offsets it reports are 1-based *rune* columns relative to the original line
-- (the `^` prefix is stripped), which is exactly what the diagnostics API
-- wants, so no column conversion is needed on that path.

local ttt = require("ttt")
local editor = require("ttt.editor")
local diag = require("ttt.diagnostics")
local events = require("ttt.events")
local sys = require("ttt.system")
local settings = require("ttt.settings")

local SOURCE = "spell"
local DEFAULT_DEBOUNCE = 500
-- aspell happily returns 60+ suggestions for a short word. Plugin items are
-- appended below the ~21-item editor menu, so every extra correction pushes
-- the useful ones further out of reach; three is enough to be worth reading.
local MAX_MENU_SUGGESTIONS = 3
local MAX_MESSAGE_SUGGESTIONS = 3

-- editor.language() returns the chroma lexer name. Map the prose ones to an
-- aspell filter mode so markup, code spans and URLs are not flagged. Languages
-- absent from this table are code, or not prose, and are skipped. An empty
-- mode means aspell's default filter, which already skips URLs.
local PROSE_MODES = {
  ["plaintext"] = "",
  ["reStructuredText"] = "",
  ["Org Mode"] = "",
  ["markdown"] = "markdown",
  ["HTML"] = "html",
  ["XML"] = "sgml",
  ["TeX"] = "tex",
}

-- Files no lexer matches are identified by name instead. Matching every
-- lexer-less file would drag in .log, .lock, .pem and friends, where a check
-- produces nothing but noise, so this is an allowlist rather than a fallback.
local PROSE_FILENAMES = {
  ["COMMIT_EDITMSG"] = true,
  ["MERGE_MSG"] = true,
  ["TAG_EDITMSG"] = true,
  ["NOTES_EDITMSG"] = true,
  ["README"] = true,
  ["CHANGELOG"] = true,
  ["CONTRIBUTING"] = true,
  ["TODO"] = true,
  ["AUTHORS"] = true,
}

-- Settings are read on demand rather than cached at load time: the settings
-- API is not wired up yet while the entry file is executing, and reading live
-- also means edits to settings.json apply without reloading the plugin.
local enabled_override = nil

local function is_enabled()
  if enabled_override ~= nil then
    return enabled_override
  end
  local v = settings.get("spell.enabled")
  if v == nil then
    return true -- on by default; the plugin was installed deliberately
  end
  return v and true or false
end

local function get_lang()
  return settings.get("spell.lang") or ""
end

local function basename(path)
  return path:match("[^/\\]+$") or path
end

-- Match a base name against an allowlist entry. Entries are literal names
-- ("COMMIT_EDITMSG") or globs ("*.adoc"); a glob is the only way to opt in a
-- whole extension, since files reaching here have no language to key on.
local function name_matches(pattern, name)
  if pattern == name then
    return true
  end
  if not pattern:find("*", 1, true) then
    return false
  end
  local escaped = pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*")
  return name:match("^" .. escaped .. "$") ~= nil
end

-- Decide whether a file is prose, and with which aspell filter mode. Returns
-- nil to skip the file. `spell.filetypes` overrides the language table -- a
-- string sets the mode, `false` disables a language -- and `spell.filenames`
-- replaces the lexer-less allowlist outright.
local function mode_for(path, language)
  local overrides = settings.get("spell.filetypes")
  if type(overrides) == "table" then
    local v = overrides[language]
    if v == false then
      return nil
    end
    if type(v) == "string" then
      return v
    end
  end

  if language ~= "" then
    return PROSE_MODES[language]
  end

  local name = basename(path)
  local allowed = settings.get("spell.filenames")
  if type(allowed) == "table" then
    for _, n in ipairs(allowed) do
      if name_matches(n, name) then
        return ""
      end
    end
    return nil
  end
  if PROSE_FILENAMES[name] then
    return ""
  end
  return nil
end

local function get_debounce()
  local ms = tonumber(settings.get("spell.debounce")) or DEFAULT_DEBOUNCE
  if ms < 50 then
    return 50
  end
  return ms
end

-- Results for the file most recently checked, as line -> array of spans, plus
-- the path they belong to so a late reply for another file cannot be consulted.
local spans_by_line = {}
local spans_path = nil

-- Bumped on every request so replies from superseded runs are dropped.
local generation = 0
local debounce_timer = nil
local missing_warned = false
local error_warned = false

-- Helpers -------------------------------------------------------------------

-- The sandbox has no utf8 library, so rune counting is done by matching UTF-8
-- lead bytes followed by their continuation bytes.
local function rune_len(s)
  local n = 0
  for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    n = n + 1
  end
  return n
end

local function split_lines(s)
  local out = {}
  local start = 1
  while true do
    local nl = s:find("\n", start, true)
    if not nl then
      if start <= #s then
        out[#out + 1] = s:sub(start)
      end
      return out
    end
    out[#out + 1] = s:sub(start, nl - 1)
    start = nl + 1
  end
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Extract the rune range [col, col+len) of a line as a string. Columns are
-- 1-based; col_to_byte converts them to the byte offsets Lua needs.
local function rune_slice(text, col, len)
  local from = editor.col_to_byte(text, col)
  local to = editor.col_to_byte(text, col + len)
  if not from or not to then
    return nil
  end
  return text:sub(from, to - 1)
end

-- aspell protocol -----------------------------------------------------------

-- Parse one result line: "& word N offset: sug1, sug2" (with suggestions) or
-- "# word offset" (none). Returns nil for anything else.
local function parse_result(s)
  local kind = s:sub(1, 1)
  if kind == "&" then
    local word, offset, rest = s:match("^&%s+(%S+)%s+%d+%s+(%d+):%s*(.*)$")
    if not word then
      return nil
    end
    local suggestions = {}
    for sug in rest:gmatch("[^,]+") do
      sug = trim(sug)
      if sug ~= "" then
        suggestions[#suggestions + 1] = sug
      end
    end
    return { col = tonumber(offset), word = word, suggestions = suggestions }
  elseif kind == "#" then
    local word, offset = s:match("^#%s+(%S+)%s+(%d+)$")
    if not word then
      return nil
    end
    return { col = tonumber(offset), word = word, suggestions = {} }
  end
  return nil
end

-- Walk aspell's reply. The first line is a version banner; after that every
-- input line contributes zero or more result lines followed by a blank line,
-- so blank lines are what advance the line counter.
local function parse_output(out)
  local found = {}
  local line_no = 0
  local first = true
  for _, raw in ipairs(split_lines(out)) do
    local skip = false
    if first then
      first = false
      if raw:sub(1, 4) == "@(#)" then
        skip = true
      end
    end
    if not skip then
      if raw == "" then
        line_no = line_no + 1
      else
        local m = parse_result(raw)
        if m then
          m.line = line_no + 1 -- editor lines are 1-based
          m.len = rune_len(m.word)
          found[#found + 1] = m
        end
      end
    end
  end
  return found
end

-- Build aspell's stdin: terse mode, then each buffer line as a data line. The
-- `^` prefix stops a line that begins with `*`, `#`, `!` and so on from being
-- read as a protocol command.
local function build_input(lines)
  local parts = { "!\n" }
  for _, line in ipairs(lines) do
    parts[#parts + 1] = "^" .. line .. "\n"
  end
  return table.concat(parts)
end

local function aspell_args(mode)
  local args = { "pipe", "--encoding=utf-8" }
  if mode ~= "" then
    args[#args + 1] = "--mode=" .. mode
  end
  local lang = get_lang()
  if lang ~= "" then
    args[#args + 1] = "--lang=" .. lang
  end
  return args
end

-- Checking ------------------------------------------------------------------

local function message_for(m)
  if #m.suggestions == 0 then
    return "\"" .. m.word .. "\" is not in the dictionary"
  end
  local shown = {}
  for i = 1, math.min(#m.suggestions, MAX_MESSAGE_SUGGESTIONS) do
    shown[i] = m.suggestions[i]
  end
  return "Did you mean: " .. table.concat(shown, ", ") .. "?"
end

local function publish(path, found)
  local items = {}
  local by_line = {}
  for _, m in ipairs(found) do
    items[#items + 1] = {
      line = m.line,
      col = m.col,
      end_line = m.line,
      end_col = m.col + m.len,
      severity = "warning",
      message = message_for(m),
      source = SOURCE,
    }
    local bucket = by_line[m.line]
    if not bucket then
      bucket = {}
      by_line[m.line] = bucket
    end
    bucket[#bucket + 1] = m
  end
  spans_by_line = by_line
  spans_path = path
  diag.publish(path, items)
end

local function clear(path)
  spans_by_line = {}
  spans_path = nil
  if path and path ~= "" then
    diag.clear(path)
  else
    diag.clear()
  end
end

local function check_now()
  if not is_enabled() then
    return
  end
  local path = editor.file_path()
  if path == nil or path == "" then
    return
  end
  local mode = mode_for(path, editor.language() or "")
  if mode == nil then
    -- Not prose: drop anything left over from a prose file in this tab.
    clear(path)
    return
  end
  if not sys.exec_async then
    return
  end

  generation = generation + 1
  local gen = generation
  local lines = editor.buffer_lines()

  sys.exec_async("aspell", aspell_args(mode), { stdin = build_input(lines) }, function(result)
    if gen ~= generation then
      return -- superseded by a newer check
    end
    if result.exit_code ~= 0 then
      local detail = trim(result.stderr or "")
      if detail == "" then
        detail = "aspell exited with code " .. tostring(result.exit_code)
      end
      if detail:find("No word lists") or detail:find("not found") then
        if not missing_warned then
          missing_warned = true
          ttt.notify("spell: " .. detail, "warn")
        end
      elseif not error_warned then
        error_warned = true
        ttt.notify("spell: " .. detail, "error")
      end
      return
    end
    error_warned = false
    publish(path, parse_output(result.stdout or ""))
  end)
end

local function schedule_check()
  if not is_enabled() then
    return
  end
  if debounce_timer then
    ttt.clear_timeout(debounce_timer)
  end
  debounce_timer = ttt.set_timeout(get_debounce(), function()
    debounce_timer = nil
    check_now()
  end)
end

-- Corrections ---------------------------------------------------------------

local function span_at(line, col)
  if spans_path ~= editor.file_path() then
    return nil
  end
  for _, m in ipairs(spans_by_line[line] or {}) do
    if col >= m.col and col < m.col + m.len then
      return m
    end
  end
  return nil
end

-- Replace a misspelling with a correction. A span can go stale between the
-- check and the user acting on it, so the word is verified in place first --
-- otherwise an edit elsewhere on the line would shift the range and the
-- replacement would mangle unrelated text.
local function apply_correction(line, m, replacement)
  local text = editor.get_line(line)
  if not text or rune_slice(text, m.col, m.len) ~= m.word then
    schedule_check()
    ttt.notify("spell: the text changed, re-checking", "warn")
    return
  end
  editor.replace(line, m.col, line, m.col + m.len, replacement)
  schedule_check()
end

local function add_to_dictionary(word)
  if word == nil or word == "" or word:find("[\r\n]") then
    return
  end
  local args = { "pipe", "--encoding=utf-8" }
  local lang = get_lang()
  if lang ~= "" then
    args[#args + 1] = "--lang=" .. lang
  end
  -- `*` adds the word to the personal dictionary, `#` flushes it to disk.
  sys.exec_async("aspell", args, { stdin = "*" .. word .. "\n#\n" }, function(result)
    if result.exit_code ~= 0 then
      ttt.notify("spell: could not add \"" .. word .. "\" to the dictionary", "error")
      return
    end
    ttt.notify("spell: added \"" .. word .. "\" to the dictionary")
    check_now()
  end)
end

editor.register_context_menu(function(line, col, word)
  if not is_enabled() then
    return {}
  end
  local m = span_at(line, col)
  if not m then
    return {}
  end
  local items = {}
  for i = 1, math.min(#m.suggestions, MAX_MENU_SUGGESTIONS) do
    local replacement = m.suggestions[i]
    items[#items + 1] = {
      label = "Correct to \"" .. replacement .. "\"",
      on_select = function()
        apply_correction(line, m, replacement)
      end,
    }
  end
  if #items > 0 then
    items[#items + 1] = { separator = true }
  end
  items[#items + 1] = {
    label = "Add \"" .. m.word .. "\" to dictionary",
    on_select = function()
      add_to_dictionary(m.word)
    end,
  }
  return items
end)

-- Commands ------------------------------------------------------------------

local function set_enabled(on)
  enabled_override = on
  settings.set("spell.enabled", on)
  if on then
    missing_warned = false
    error_warned = false
    check_now()
  else
    clear(editor.file_path())
  end
  ttt.notify("spell: spell check " .. (on and "enabled" or "disabled"))
end

local function toggle()
  set_enabled(not is_enabled())
end

local function add_word_at_cursor()
  local cur = editor.cursor()
  local m = span_at(cur.line, cur.col)
  if not m then
    ttt.notify("spell: no misspelling at the cursor", "warn")
    return
  end
  add_to_dictionary(m.word)
end

-- Correct the word at the cursor without reaching for the mouse. The command
-- line opens prefilled with the best suggestion and lists the runners-up in
-- the prefix, so accepting is one keypress and choosing another is a quick
-- edit.
local function correct_at_cursor()
  local cur = editor.cursor()
  local m = span_at(cur.line, cur.col)
  if not m then
    ttt.notify("spell: no misspelling at the cursor", "warn")
    return
  end
  if #m.suggestions == 0 then
    ttt.notify("spell: no suggestions for \"" .. m.word .. "\"", "warn")
    return
  end
  local alternatives = {}
  for i = 2, math.min(#m.suggestions, MAX_MENU_SUGGESTIONS) do
    alternatives[#alternatives + 1] = m.suggestions[i]
  end
  local prefix = m.word .. " -> "
  if #alternatives > 0 then
    prefix = m.word .. " (" .. table.concat(alternatives, ", ") .. ") -> "
  end
  local line = cur.line
  ttt.command_line.show({
    prefix = prefix,
    text = m.suggestions[1],
    on_submit = function(text)
      text = trim(text or "")
      if text ~= "" then
        apply_correction(line, m, text)
      end
    end,
  })
end

-- Startup -------------------------------------------------------------------

ttt.register({
  commands = {
    { id = "spell.toggle", title = "Spell Check: Toggle", handler = toggle },
    { id = "spell.check", title = "Spell Check: Check Now", handler = check_now },
    {
      id = "spell.correct",
      title = "Spell Check: Correct Word at Cursor",
      handler = correct_at_cursor,
    },
    {
      id = "spell.addWord",
      title = "Spell Check: Add Word at Cursor to Dictionary",
      handler = add_word_at_cursor,
    },
  },
})

events.on("editor.change", schedule_check)
events.on("file.open", schedule_check)
events.on("tab.change", schedule_check)

schedule_check()
