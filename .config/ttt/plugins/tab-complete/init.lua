-- tab-complete: Cursor-style inline completions for ttt.
--
-- Asks an OpenAI-compatible /v1/completions endpoint (LM Studio by default)
-- for a fill-in-the-middle completion after a typing pause and draws the
-- result as ghost text at the cursor through ttt.inline. Tab accepts, Esc
-- dismisses; nothing here changes the buffer until Tab.
--
-- See README.md for the upstream-merge notes and the core change it needs.

local ttt = require("ttt")
local editor = require("ttt.editor")
local net = require("ttt.net")
local json = require("ttt.json")
local events = require("ttt.events")
local inline = require("ttt.inline")
local storage = require("ttt.storage")

local DEFAULTS = {
  enabled = true,
  endpoint = "http://127.0.0.1:1234/v1/completions",
  model = "luau-qwen3-4b-fim-v0.1",
  template = "chatml",
  max_tokens = 96,
  debounce = 250,
  context = 4000,
  extensions = "go,lua,luau,py,js,jsx,ts,tsx,rs,c,h,cc,cpp,hpp,java,kt,rb,php,cs,"
    .. "sh,bash,zsh,sql,html,css,scss,json,yaml,yml,toml,md",
}

-- Config lives in the plugin's own storage: ttt.settings only persists keys
-- that already exist in ttt's settings schema.
local cache = {}

local function setting(key)
  if cache[key] ~= nil then return cache[key] end
  local ok, value = pcall(storage.get, key)
  if ok and value ~= nil then cache[key] = value else value = DEFAULTS[key] end
  return value
end

local function save_setting(key, value)
  local ok, err = pcall(storage.set, key, value)
  if not ok then
    ttt.log("warn", "tab-complete: cannot save " .. key .. ": " .. tostring(err))
    return false
  end
  cache[key] = value
  return true
end

-- Fill-in-the-middle prompt formats. The model only continues a prompt built
-- the way it was trained, so `template` must match the loaded model family.
local TEMPLATES = {
  qwen = {
    stop = { "<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>", "<|file_sep|>", "<|endoftext|>" },
    format = function(prefix, suffix)
      return "<|fim_prefix|>" .. prefix .. "<|fim_suffix|>" .. suffix .. "<|fim_middle|>"
    end,
  },
  starcoder = {
    stop = { "<fim_prefix>", "<fim_suffix>", "<fim_middle>", "<file_sep>", "<|endoftext|>" },
    format = function(prefix, suffix)
      return "<fim_prefix>" .. prefix .. "<fim_suffix>" .. suffix .. "<fim_middle>"
    end,
  },
  codellama = {
    stop = { "<EOT>", "<PRE>", "<SUF>", "<MID>" },
    format = function(prefix, suffix)
      return "<PRE> " .. prefix .. " <SUF>" .. suffix .. " <MID>"
    end,
  },
  codestral = {
    stop = { "[SUFFIX]", "[PREFIX]" },
    format = function(prefix, suffix)
      return "[SUFFIX]" .. suffix .. "[PREFIX]" .. prefix
    end,
  },
  glm = {
    stop = { "<|code_prefix|>", "<|code_suffix|>", "<|code_middle|>", "<|endoftext|>" },
    format = function(prefix, suffix)
      return "<|code_prefix|>" .. prefix .. "<|code_suffix|>" .. suffix .. "<|code_middle|>"
    end,
  },
  -- Models trained on ChatML-wrapped FIM (Luau-Qwen3-4B-FIM): the wrapper and
  -- the suffix-before-prefix order are what they were trained with.
  chatml = {
    stop = { "<|im_end|>", "</s>", "<|repo_name|>", "<|file_sep|>",
      "<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>", "```" },
    format = function(prefix, suffix)
      local path = editor.file_path() or ""
      local filename = string.match(path, "[^/\\]+$") or path
      local repo = string.match(path, "([^/\\]+)[/\\][^/\\]+$") or ""
      return "<|im_start|>system\nYou are a code completion assistant.<|im_end|>\n"
        .. "<|im_start|>user\n<|repo_name|>" .. repo .. "<|file_sep|>" .. filename
        .. "<|fim_suffix|>" .. suffix .. "<|fim_prefix|>" .. prefix
        .. "<|fim_middle|><|im_end|>\n<|im_start|>assistant\n"
    end,
  },
}

local warned_template
local function template()
  local name = setting("template")
  if TEMPLATES[name] then return TEMPLATES[name] end
  if warned_template ~= name then
    warned_template = name
    ttt.log("warn", "tab-complete: unknown template " .. tostring(name) .. ", using qwen")
  end
  return TEMPLATES.qwen
end

local function strip_stops(text, stops)
  local cut = #text
  for _, token in ipairs(stops) do
    local i = string.find(text, token, 1, true)
    if i and i - 1 < cut then cut = i - 1 end
  end
  return string.sub(text, 1, cut)
end

local function clean(raw, stops)
  local text = strip_stops(raw or "", stops)
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "[ \t]+$", "")
  text = string.gsub(text, "\n+$", "")
  if text == "" or string.match(text, "^%s*$") then return nil end
  return text
end

-- FIM models often keep generating past the cursor and re-emit the text that
-- already follows it, which would duplicate code on accept.
local function trim_overlap(text, suffix)
  for k = math.min(#text, #suffix), 1, -1 do
    if string.sub(text, -k) == string.sub(suffix, 1, k) then
      return string.sub(text, 1, #text - k)
    end
  end
  return text
end

local function cursor_position()
  local c = editor.cursor()
  return c.line - 1, c.col - 1
end

local function cursor_byte(line_text, col)
  return editor.col_to_byte(line_text, col + 1)
end

local function prefix_text(lines, line, col, limit)
  local parts = {}
  -- `line` is 0-based; the buffer arrays are 1-based.
  local current = line + 1
  for i = math.max(1, current - 199), current do
    local text = lines[i]
    if i == current then
      text = string.sub(text, 1, cursor_byte(text, col) - 1)
    end
    parts[#parts + 1] = text
  end
  local joined = table.concat(parts, "\n")
  if #joined > limit then joined = string.sub(joined, -limit) end
  return joined
end

local function suffix_text(lines, line, col, limit)
  local parts = {}
  local current = line + 1
  for i = current, math.min(#lines, current + 200) do
    local text = lines[i]
    if i == current then
      text = string.sub(text, cursor_byte(text, col))
    end
    parts[#parts + 1] = text
  end
  local joined = table.concat(parts, "\n")
  if #joined > limit then joined = string.sub(joined, 1, limit) end
  return joined
end

local function file_allowed()
  local path = editor.file_path()
  if not path or path == "" then return false end
  local ext = string.lower(string.match(path, "%.([%w]+)$") or "")
  local list = setting("extensions") or ""
  if list == "" then return true end
  for item in string.gmatch(list, "[^,%s]+") do
    if string.lower(item) == ext then return true end
  end
  return false
end

-- The editor draws ghost text over the blank tail of the cursor line only, so
-- a request is pointless when real text follows the cursor.
local function at_line_end(lines, line, col)
  local text = lines[line + 1] or ""
  local tail = string.sub(text, cursor_byte(text, col))
  return string.match(tail, "^[ \t]*$") ~= nil
end

local pending = nil -- { text = inserted text, display = one-line ghost }
local generation = 0
local request_timer = nil

local function clear()
  pending = nil
  if inline.clear then inline.clear() end
end

local function request_now()
  if not setting("enabled") then return end
  if not inline.set then
    ttt.log("error", "tab-complete: the plugin needs the editor.decorations permission")
    return
  end
  if not file_allowed() then return end
  local sel = editor.selection()
  if sel and sel.active then return end

  local line, col = cursor_position()
  local lines = editor.buffer_lines()
  if #lines == 0 or line < 0 or line >= #lines then return end
  if not at_line_end(lines, line, col) then return end

  local limit = tonumber(setting("context")) or 4000
  local prefix = prefix_text(lines, line, col, limit)
  local suffix = suffix_text(lines, line, col, limit)
  -- A prompt containing the format's own markers would make the model
  -- continue our prompt text instead of the code.
  if string.find(prefix, "<|fim", 1, true) or string.find(suffix, "<|fim", 1, true) then return end
  if string.find(prefix, "<fim_", 1, true) or string.find(suffix, "<fim_", 1, true) then return end

  generation = generation + 1
  local gen = generation
  local tmpl = template()
  local body = {
    model = setting("model"),
    prompt = tmpl.format(prefix, suffix),
    max_tokens = math.floor(tonumber(setting("max_tokens")) or 96),
    temperature = 0,
    stream = false,
    stop = tmpl.stop,
  }
  local headers = { ["Content-Type"] = "application/json" }
  local key = setting("api_key")
  if key and key ~= "" then headers["Authorization"] = "Bearer " .. key end

  local ok, err = pcall(net.post_async, setting("endpoint"), { headers = headers, body = json.encode(body) },
    function(resp)
      if gen ~= generation then return end -- superseded by a newer keystroke
      if resp.status ~= 200 then
        ttt.log("warn", "tab-complete: HTTP " .. tostring(resp.status) .. " " .. tostring(resp.error or ""))
        return
      end
      local decoded = json.decode(resp.body)
      local choice = decoded and decoded.choices and decoded.choices[1]
      local text = clean(choice and choice.text, tmpl.stop)
      if not text then return end
      text = trim_overlap(text, suffix)
      -- The ghost text is one row, so it has to show exactly what Tab
      -- inserts. A completion that starts on the next line keeps one leading
      -- newline (so it lands as its own indented line) and previews that
      -- line behind a ↵ marker; anything past it is dropped, not inserted.
      local display = text
      if string.find(text, "^[ \t]*\n") then
        local body = string.gsub(text, "^[ \t]*\n+", "")
        body = string.match(body, "^[^\n]*")
        body = string.gsub(body, "[ \t]+$", "")
        if body == "" or string.match(body, "^%s*$") then return end
        text = "\n" .. body
        display = "↵ " .. string.gsub(body, "^[ \t]+", "")
      else
        text = string.match(text, "^[^\n]*")
        text = string.gsub(text, "[ \t]+$", "")
        if text == "" or string.match(text, "^%s*$") then return end
        display = text
      end
      -- The model sometimes repeats what is already after the cursor.
      if #suffix >= #text and string.sub(suffix, 1, #text) == text then return end
      pending = { text = text }
      inline.set(display, { style = "muted" })
    end)
  if not ok then
    ttt.log("warn", "tab-complete: " .. tostring(err))
  end
end

local function schedule()
  clear()
  if not setting("enabled") then return end
  generation = generation + 1 -- replies already in flight are stale now
  if request_timer then ttt.clear_timeout(request_timer) end
  request_timer = ttt.set_timeout(math.floor(tonumber(setting("debounce")) or 250), function()
    request_timer = nil
    request_now()
  end)
end

local function accept()
  if not pending then return false end
  local text = pending.text
  clear()
  generation = generation + 1
  local line, col = cursor_position()
  editor.begin_undo_group()
  editor.insert(line + 1, col + 1, text)
  editor.end_undo_group()
  local rows = select(2, string.gsub(text, "\n", ""))
  local last = string.match(text, "([^\n]*)$")
  local runes = #last == 0 and 0 or editor.byte_to_col(last, #last)
  local end_col = rows == 0 and col + 1 + runes or 1 + runes
  editor.set_cursor(line + 1 + rows, end_col)
  return true
end

events.on("key.press", function(ev)
  if ev.mod then return false end
  if ev.key == "Tab" and pending then
    return accept()
  end
  if ev.key == "Esc" and pending then
    clear()
    return true
  end
  return false
end)

events.on("editor.change", schedule)
events.on("cursor.change", schedule)
events.on("tab.change", clear)

local function toggle()
  local was_enabled = setting("enabled")
  save_setting("enabled", not was_enabled)
  if was_enabled then clear() end
  ttt.notify("Tab complete " .. (was_enabled and "off" or "on"))
end

local function request_command()
  if request_timer then
    ttt.clear_timeout(request_timer)
    request_timer = nil
  end
  clear()
  request_now()
end

local function configure()
  local endpoint = setting("endpoint")
  local model = setting("model")
  local template_name = setting("template")
  ttt.open_dialog({
    title = "Tab Complete",
    width = 72,
    height = 12,
    render = function(panel)
      panel:label("OpenAI-compatible completion endpoint:")
      panel:input({ value = endpoint, on_change = function(v) endpoint = v end })
      panel:label("Model:")
      panel:input({ value = model, on_change = function(v) model = v end })
      panel:label("FIM template: chatml, qwen, starcoder, codellama, codestral, glm")
      panel:input({ value = template_name, on_change = function(v) template_name = v end })
      panel:button({
        label = "Save",
        on_click = function()
          if not TEMPLATES[template_name] then
            ttt.notify("Tab complete: unknown template " .. tostring(template_name))
            return
          end
          save_setting("endpoint", endpoint)
          save_setting("model", model)
          save_setting("template", template_name)
          ttt.close_dialog()
          ttt.notify("Tab complete settings saved")
        end,
      })
    end,
  })
end

ttt.register({
  commands = {
    { id = "tabcomplete.request", title = "Tab Complete: Request Now", handler = request_command },
    { id = "tabcomplete.toggle", title = "Tab Complete: Toggle", handler = toggle },
    { id = "tabcomplete.configure", title = "Tab Complete: Configure", handler = configure },
  },
  keybindings = {
    { key = "ctrl+k a", command = "tabcomplete.request" },
  },
})
