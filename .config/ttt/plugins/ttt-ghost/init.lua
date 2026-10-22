local ttt = require("ttt")
local editor = require("ttt.editor")
local events = require("ttt.events")
local net = require("ttt.net")
local sys = require("ttt.system")
local json = require("ttt.json")
local storage = require("ttt.storage")

local DEBOUNCE_MS = 300
local MAX_PREFIX_LINES = 60
local MAX_SUFFIX_LINES = 10
local MAX_PROMPT_CHARS = 6000
local MAX_GHOST_LINES = 10
local MAX_LINE_COUNT = 30000

local ghost = nil
local gen = 0
local timer = nil
local pending = false
local warned_no_key = false
local last = { status = "-", note = "no request yet" }

local function note(s)
  return (s or ""):gsub("%s+", " "):sub(1, 120)
end

local function cfg(key, env_name, default)
  local v = storage.get("ghost." .. key)
  if v ~= nil and v ~= "" then
    return v
  end
  v = sys.env(env_name)
  if v ~= nil and v ~= "" then
    return v
  end
  return default
end

local function base_url()
  return cfg("base_url", "OPENAI_BASE_URL", "https://openrouter.ai/api/v1")
end

local function api_key()
  local v = storage.get("ghost.api_key")
  if v ~= nil and v ~= "" then
    return v
  end
  v = sys.env("OPENAI_API_KEY")
  if v ~= nil and v ~= "" then
    return v
  end
  v = sys.env("OPENROUTER_API_KEY")
  if v ~= nil and v ~= "" then
    return v
  end
  return ""
end

local function model()
  return cfg("model", "OPENAI_MODEL", "openai/gpt-4o-mini")
end

local function enabled()
  local v = storage.get("ghost.enabled")
  if v == nil then
    return true
  end
  return v
end

local function clear_ghost()
  ghost = nil
  editor.clear_virtual_text()
end

local function is_local_url(url)
  return url:match("^https?://localhost[:/]")
    or url:match("^https?://127%.")
    or url:match("^https?://10%.")
    or url:match("^https?://192%.168%.")
    or url:match("^https?://172%.1[6-9]%.")
    or url:match("^https?://172%.2[0-9]%.")
    or url:match("^https?://172%.3[0-1]%.")
    or url:match("^https?://%[::1%]")
end

local function sanitize(text, suffix)
  text = text:gsub("```%w*\n?", ""):gsub("```", "")
  if suffix ~= "" and text:sub(1, #suffix) == suffix then
    text = text:sub(#suffix + 1)
  end
  text = text:gsub("^\n+", "")
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line:gsub("%s+$", "")
    if #lines >= MAX_GHOST_LINES then
      break
    end
  end
  while #lines > 0 and lines[#lines] == "" do
    lines[#lines] = nil
  end
  while #lines > 0 and lines[1] == "" do
    table.remove(lines, 1)
  end
  return lines
end

local function build_context()
  local pos = editor.cursor()
  local all = editor.buffer_lines()
  local cur = editor.current_line()
  local cursor_byte = editor.col_to_byte(cur, pos.col)
  local before_cursor = cur:sub(1, cursor_byte - 1)
  local after_cursor = cur:sub(cursor_byte)
  local from = math.max(1, pos.line - MAX_PREFIX_LINES)
  local parts = {}
  for i = from, pos.line - 1 do
    parts[#parts + 1] = all[i]
  end
  parts[#parts + 1] = before_cursor
  local prefix = table.concat(parts, "\n")
  if #prefix > MAX_PROMPT_CHARS then
    prefix = prefix:sub(#prefix - MAX_PROMPT_CHARS + 1)
  end
  local tail = {after_cursor}
  for i = pos.line + 1, math.min(#all, pos.line + MAX_SUFFIX_LINES) do
    tail[#tail + 1] = all[i]
  end
  return pos, prefix, table.concat(tail, "\n"), cur
end

local function show_ghost(my_gen, pos, cur_snapshot, lines)
  if my_gen ~= gen then
    last = { status = "drop", note = "stale" }
    ttt.log("info", "ghost drop: stale")
    return
  end
  if #lines == 0 then
    last = { status = "drop", note = "empty" }
    ttt.log("info", "ghost drop: empty")
    return
  end
  local now = editor.cursor()
  if now.line ~= pos.line or now.col ~= pos.col then
    last = { status = "drop", note = "cursor-moved" }
    ttt.log("info", "ghost drop: cursor-moved")
    return
  end
  if editor.current_line() ~= cur_snapshot then
    last = { status = "drop", note = "line-changed" }
    ttt.log("info", "ghost drop: line-changed")
    return
  end
  ghost = lines
  editor.set_virtual_text(pos.line, true, lines)
  last = { status = "shown", note = #lines .. " lines" }
  ttt.log("info", "ghost show " .. #lines .. " lines @" .. pos.line)
end

local function handle_result(my_gen, pos, cur_snapshot, suffix, status, body, err)
  pending = false
  if my_gen ~= gen then
    last = { status = "drop", note = "stale" }
    ttt.log("info", "ghost drop: stale")
    return
  end
  if err ~= nil and err ~= "" then
    last = { status = "error", note = note(err) }
    ttt.log("error", "ghost request failed: " .. err)
    return
  end
  if status ~= 200 then
    last = { status = tostring(status), note = note(body) }
    ttt.log("error", "ghost request status " .. tostring(status) .. ": " .. (body or ""):sub(1, 200))
    ttt.notify("Ghost: completion failed (status " .. tostring(status) .. ")", "error")
    return
  end
  local ok, data = pcall(json.decode, body)
  if not ok or type(data) ~= "table" then
    last = { status = "parse", note = "bad json" }
    ttt.log("error", "ghost: could not parse response")
    return
  end
  local choice = data.choices and data.choices[1]
  local text = choice and choice.message and choice.message.content
  if type(text) ~= "string" or text == "" then
    last = { status = "empty", note = "no content" }
    ttt.log("info", "ghost drop: empty content")
    return
  end
  ttt.log("info", "ghost res 200 content=" .. #text .. "ch")
  show_ghost(my_gen, pos, cur_snapshot, sanitize(text, suffix))
end

local function request_completion()
  if not enabled() or pending then
    return
  end
  if editor.line_count() > MAX_LINE_COUNT then
    return
  end
  local pos, prefix, suffix, cur = build_context()
  if prefix:match("^%s*$") then
    return
  end
  local url = base_url() .. "/chat/completions"
  local key = api_key()
  if key == "" and not is_local_url(url) then
    if not warned_no_key then
      warned_no_key = true
      ttt.notify("Ghost: no API key — run Ghost: Set API Key or set OPENAI_API_KEY", "warn")
    end
    return
  end
  local my_gen = gen
  local host = url:match("^https?://([^/]+)") or url
  last = { status = "...", note = "sent" }
  ttt.log("info", "ghost req " .. host .. " " .. model() .. " prefix=" .. #prefix .. "ch")
  local body = json.encode({
    model = model(),
    stream = false,
    temperature = 0.2,
    max_tokens = 150,
    messages = {
      {
        role = "system",
        content = "You are an inline code completion engine. Reply with ONLY the raw code that continues at the cursor. No explanations. No markdown fences. Complete the partial line first, then add following lines if clearly implied.",
      },
      {
        role = "user",
        content = "File: "
          .. editor.file_name()
          .. " ("
          .. editor.language()
          .. ")\nCode before cursor:\n"
          .. prefix
          .. "\n<cursor>\nCode after cursor:\n"
          .. suffix
          .. "\nContinue at <cursor>:",
      },
    },
  })
  pending = true
  if is_local_url(url) then
    local args = {
      "-sS", "-f", "-m", "30", "-X", "POST", url,
      "-H", "Content-Type: application/json",
      "-H", "HTTP-Referer: https://github.com/eugenioenko/ttt",
      "-H", "X-Title: ttt-ghost",
    }
    if key ~= "" then
      args[#args + 1] = "-H"
      args[#args + 1] = "Authorization: Bearer " .. key
    end
    args[#args + 1] = "-d"
    args[#args + 1] = "@-"
    sys.exec_async("curl", args, { stdin = body }, function(result)
      if result.exit_code ~= 0 then
        handle_result(my_gen, pos, cur, suffix, 0, "", result.stderr ~= "" and result.stderr or "curl failed")
      else
        handle_result(my_gen, pos, cur, suffix, 200, result.stdout, "")
      end
    end)
  else
    local headers = {
      ["Content-Type"] = "application/json",
      ["HTTP-Referer"] = "https://github.com/eugenioenko/ttt",
      ["X-Title"] = "ttt-ghost",
    }
    if key ~= "" then
      headers["Authorization"] = "Bearer " .. key
    end
    net.post_async(url, { headers = headers, body = body }, function(resp)
      handle_result(my_gen, pos, cur, suffix, resp.status, resp.body or "", resp.error or "")
    end)
  end
end

local function schedule()
  gen = gen + 1
  clear_ghost()
  if timer then
    ttt.clear_timeout(timer)
    timer = nil
  end
  if not enabled() then
    return
  end
  timer = ttt.set_timeout(DEBOUNCE_MS, function()
    timer = nil
    request_completion()
  end)
end

local function accept()
  if not ghost then
    return false
  end
  local pos = editor.cursor()
  local text = table.concat(ghost, "\n")
  local cur = editor.current_line()
  local b = editor.col_to_byte(cur, pos.col)
  editor.begin_undo_group()
  editor.insert(pos.line, pos.col, text)
  editor.end_undo_group()
  if #ghost == 1 then
    local new_line = cur:sub(1, b - 1) .. text .. cur:sub(b)
    editor.set_cursor(pos.line, editor.byte_to_col(new_line, b + #text))
  else
    local last_full = ghost[#ghost] .. cur:sub(b)
    editor.set_cursor(pos.line + #ghost - 1, editor.byte_to_col(last_full, #ghost[#ghost] + 1))
  end
  clear_ghost()
  return true
end

events.on("editor.change", function()
  schedule()
end)

events.on("cursor.change", function()
  schedule()
end)

events.on("tab.change", function()
  gen = gen + 1
  clear_ghost()
end)

events.on("file.save", function()
  gen = gen + 1
  clear_ghost()
end)

events.on("key.press", function(ev)
  if not ghost then
    return false
  end
  if ev.key == "Tab" and not ev.mod then
    return accept()
  end
  if ev.key == "Escape" then
    clear_ghost()
    return true
  end
  return false
end)

local function prompt(title, initial, on_ok)
  ttt.command_line.show({
    prefix = title .. ": ",
    text = initial or "",
    on_submit = function(text)
      on_ok(text)
    end,
    on_cancel = function() end,
  })
end

local function mask_key(key)
  if key == "" then
    return "(not set)"
  end
  if #key <= 8 then
    return "(set)"
  end
  return "(set, ..." .. key:sub(#key - 3) .. ")"
end

ttt.register({
  commands = {
    {
      id = "ghost.completeNow",
      title = "Ghost: Complete Now",
      handler = function()
        gen = gen + 1
        request_completion()
      end,
    },
    {
      id = "ghost.enable",
      title = "Ghost: Enable",
      handler = function()
        storage.set("ghost.enabled", true)
        ttt.notify("Ghost: enabled")
        schedule()
      end,
    },
    {
      id = "ghost.disable",
      title = "Ghost: Disable",
      handler = function()
        storage.set("ghost.enabled", false)
        gen = gen + 1
        clear_ghost()
        ttt.notify("Ghost: disabled")
      end,
    },
    {
      id = "ghost.setKey",
      title = "Ghost: Set API Key",
      handler = function()
        prompt("API key", "", function(text)
          storage.set("ghost.api_key", text)
          warned_no_key = false
          ttt.notify("Ghost: API key saved")
        end)
      end,
    },
    {
      id = "ghost.setBaseUrl",
      title = "Ghost: Set Base URL",
      handler = function()
        prompt("Base URL", base_url(), function(text)
          storage.set("ghost.base_url", text:gsub("/+$", ""))
          ttt.notify("Ghost: base URL saved")
        end)
      end,
    },
    {
      id = "ghost.setModel",
      title = "Ghost: Set Model",
      handler = function()
        prompt("Model", model(), function(text)
          storage.set("ghost.model", text)
          ttt.notify("Ghost: model saved")
        end)
      end,
    },
    {
      id = "ghost.status",
      title = "Ghost: Show Status",
      handler = function()
        ttt.notify(
          "Ghost: "
            .. (enabled() and "on" or "off")
            .. " | "
            .. base_url()
            .. " | "
            .. model()
            .. " | key "
            .. mask_key(api_key())
            .. " | last "
            .. last.status
            .. " "
            .. last.note
        )
      end,
    },
    {
      id = "ghost.testSuggestion",
      title = "Ghost: Test Suggestion",
      handler = function()
        local pos = editor.cursor()
        ghost = { "-- test suggestion", "-- press Tab to accept" }
        editor.set_virtual_text(pos.line, true, ghost)
      end,
    },
  },
})
