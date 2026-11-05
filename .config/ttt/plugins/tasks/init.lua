local ttt = require("ttt")
local fs = require("ttt.fs")
local sys = require("ttt.system")
local editor = require("ttt.editor")
local events = require("ttt.events")

local TASKS_DIR = "tasks"
local POLL_MS = 2000
local MISSING = "missing:"

local state = {
	panel = nil,
	roots = {},
	ready = false,
	syncing = false,
	polling = false,
	entries = {},
	scanned = {},
	is_dir = {},
	badges = {},
	signature = "",
	automation = nil,
	session_error = nil,
}

local function base(path)
	return path:match("([^/\\]+)$") or path
end

local function dirname(path)
	if not path then
		return nil
	end
	return path:match("^(.*)[/\\][^/\\]*$")
end

local function join(dir, name)
	local last = dir:sub(-1)
	if last == "/" or last == "\\" then
		return dir .. name
	end
	return dir .. "/" .. name
end

-- fs.list only returns names, so a directory has to be listed to find its tasks/
-- child and prove it is a directory rather than a file.
local function find_tasks(folder)
	local entries = fs.list(folder)
	if not entries then
		return nil
	end
	for _, e in ipairs(entries) do
		if e.name == TASKS_DIR and e.is_dir then
			return join(folder, TASKS_DIR)
		end
	end
	return nil
end

local function scan(dir)
	local raw = fs.list(dir)
	if not raw then
		state.entries[dir] = nil
		state.scanned[dir] = nil
		return nil
	end
	local list = {}
	for _, e in ipairs(raw) do
		list[#list + 1] = {
			name = e.name,
			path = join(dir, e.name),
			is_dir = e.is_dir == true,
		}
	end
	table.sort(list, function(a, b)
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name:lower() < b.name:lower()
	end)
	state.entries[dir] = list
	state.scanned[dir] = true
	for _, e in ipairs(list) do
		state.is_dir[e.path] = e.is_dir
	end
	return list
end

-- Badges come from the planning templates' frontmatter. Cached because render
-- runs on every frame and must not touch the disk; invalidated on save.
local function status_of(path)
	if not path:match("%.md$") then
		return nil
	end
	local cached = state.badges[path]
	if cached ~= nil then
		if cached == false then
			return nil
		end
		return cached
	end
	local status = nil
	local text = fs.read(path)
	if text and text:sub(1, 3) == "---" then
		local close = text:find("\n%-%-%-", 4)
		local block = text:sub(1, close and close + 3 or 400)
		status = block:match("\nstatus:%s*([%w_%-%.]+)")
	end
	state.badges[path] = status or false
	return status
end

local function children_of(dir)
	local out = {}
	for _, e in ipairs(state.entries[dir] or {}) do
		local node = {
			id = e.path,
			label = e.name,
			muted = e.name:sub(1, 1) == ".",
		}
		if e.is_dir then
			node.expandable = true
			if state.entries[e.path] then
				node.children = children_of(e.path)
			end
		else
			local status = status_of(e.path)
			if status then
				node.label = e.name .. " - " .. status
				node.muted = node.muted or status == "done"
			else
				node.label = e.name
			end
		end
		out[#out + 1] = node
	end
	return out
end

-- One workspace folder renders its tasks/ contents at the top level. Several
-- folders need a level above them, since a plugin owns a single sidebar tab.
local function build_items()
	local with_tasks = 0
	for _, root in ipairs(state.roots) do
		if root.tasks then
			with_tasks = with_tasks + 1
		end
	end
	if with_tasks == 0 then
		return {}, false
	end
	if #state.roots == 1 then
		return children_of(state.roots[1].tasks), true
	end
	local items = {}
	for _, root in ipairs(state.roots) do
		if root.tasks then
			items[#items + 1] = {
				id = root.tasks,
				label = root.name,
				expandable = true,
				expanded = true,
				children = children_of(root.tasks),
			}
		else
			items[#items + 1] = {
				id = MISSING .. root.path,
				label = root.name,
				expandable = true,
				expanded = true,
				children = {
					{ id = MISSING .. root.path .. "/tasks", label = "no tasks/", muted = true },
				},
			}
		end
	end
	return items, true
end

local function open_node(node)
	if not node or not node.id or node.id == "" then
		return
	end
	if node.id:sub(1, #MISSING) == MISSING then
		return
	end
	if state.is_dir[node.id] then
		return
	end
	ttt.open_file(node.id)
end

-- The tree calls on_select for every selection change (arrow keys, expansion),
-- so opening happens on activate only: Enter or a click on a file row.
local function activate_node(command, node)
	if command == "activate" then
		open_node(node)
	end
end

local function expand_node(node)
	if not node or not node.id or state.entries[node.id] then
		return
	end
	scan(node.id)
	if state.panel then
		state.panel:redraw()
	end
end

-- Re-reads every directory already materialized in the tree and reports
-- whether anything visible changed, so the poll never redraws for nothing.
local function rescan()
	local sig = {}
	for _, root in ipairs(state.roots) do
		root.tasks = find_tasks(root.path)
		if root.tasks then
			if not state.scanned[root.tasks] then
				scan(root.tasks)
			end
			sig[#sig + 1] = root.tasks
		end
	end
	local dirs = {}
	for dir in pairs(state.scanned) do
		dirs[#dirs + 1] = dir
	end
	table.sort(dirs)
	for _, dir in ipairs(dirs) do
		local list = scan(dir)
		if list then
			local parts = {}
			for _, e in ipairs(list) do
				parts[#parts + 1] = (e.is_dir and "d" or "f") .. e.name
			end
			sig[#sig + 1] = dir .. "=" .. table.concat(parts, ",")
		end
	end
	local next_sig = table.concat(sig, "|")
	if next_sig == state.signature then
		return false
	end
	state.signature = next_sig
	return true
end

local function refresh()
	if rescan() and state.panel then
		state.panel:redraw()
	end
end

-- ttt.automation is only preloaded once the plugin is wired, which happens
-- after this chunk runs, so the module is resolved lazily on first use.
local function automation_module()
	if state.automation == nil then
		local ok, mod = pcall(require, "ttt.automation")
		state.automation = (ok and mod) or false
	end
	return state.automation or nil
end

-- Builds have no workspace API before ttt.automation, but paths are sandboxed
-- to the workspace folders, so the highest ancestor that still lists is the
-- workspace root containing it.
local function accessible_root(start)
	local best = nil
	local dir = start
	while dir and dir ~= "" do
		if not fs.list(dir) then
			break
		end
		best = dir
		local parent = dirname(dir)
		if parent == dir then
			break
		end
		dir = parent
	end
	return best
end

local function local_roots()
	local roots = {}
	local seen = {}
	local candidates = { sys.env("PWD"), dirname(editor.file_path() or "") }
	for _, path in ipairs(candidates) do
		local root = accessible_root(path)
		if root and not seen[root] then
			seen[root] = true
			roots[#roots + 1] = { path = root, name = base(root) }
		end
	end
	return roots
end

local function sync_session(force)
	if state.syncing then
		return
	end
	if state.ready and not force then
		return
	end
	local automation = automation_module()
	if automation then
		state.syncing = true
		automation.run("session", "", function(result, err)
			state.syncing = false
			state.ready = true
			if err then
				state.session_error = tostring(err)
			end
			local roots = {}
			for _, path in ipairs((result and result.workspaces) or {}) do
				roots[#roots + 1] = { path = path, name = base(path), tasks = nil }
			end
			state.roots = roots
			refresh()
		end)
		return
	end
	state.ready = true
	state.roots = local_roots()
	refresh()
end

local function start_poll()
	if state.polling then
		return
	end
	state.polling = true
	ttt.set_interval(POLL_MS, function()
		if state.ready then
			refresh()
		end
	end)
end

local function render_empty(panel)
	panel:title({ text = "TASKS", margin_top = 1, margin_left = 1 })
	if state.session_error then
		panel:label({ text = state.session_error, style = "warning", margin_top = 1, margin_left = 1 })
		return
	end
	if #state.roots == 0 then
		panel:label({ text = "No workspace folder detected", margin_top = 1, margin_left = 1 })
		panel:label({ text = "Open a project folder, then reopen this tab", style = "muted", margin_left = 1 })
		return
	end
	panel:label({ text = "No tasks/ folder in this workspace", margin_top = 1, margin_left = 1 })
	panel:label({ text = "Create a tasks/ folder to get started", style = "muted", margin_left = 1 })
end

local function render(panel)
	state.panel = panel
	start_poll()
	if not state.ready then
		sync_session(false)
	end
	if not state.ready then
		panel:label({ text = "Loading workspace…", style = "muted", margin_top = 1, margin_left = 1 })
		return
	end
	local items, has_tasks = build_items()
	if not has_tasks then
		render_empty(panel)
		return
	end
	if #items == 0 then
		panel:label({ text = "tasks/ is empty", style = "muted", margin_top = 1, margin_left = 1 })
		return
	end
	panel:tree({
		items = items,
		indent = 2,
		on_command = activate_node,
		on_expand = expand_node,
	})
end

local function reveal_panel()
	if type(ttt.focus_panel) == "function" then
		ttt.focus_panel("sidebar")
	elseif type(ttt.show_panel) == "function" then
		ttt.show_panel("sidebar")
	else
		ttt.notify("Tasks: click the Tasks tab in the sidebar")
	end
end

local function show()
	sync_session(true)
	reveal_panel()
end

ttt.register({
	sidebar = {
		title = "Tasks",
		actions = {
			{ label = "Refresh", command = "refresh" },
		},
		on_action = function(command)
			if command == "refresh" then
				refresh()
			end
		end,
		render = render,
	},
	commands = {
		{ id = "tasks.open", title = "Tasks: Show Tasks Folder", handler = show },
		{ id = "tasks.refresh", title = "Tasks: Refresh", handler = refresh },
	},
	keybindings = {
		{ key = "ctrl+k t", command = "tasks.open" },
	},
})

events.on("file.save", function(path)
	state.badges[path] = nil
	if state.panel then
		state.panel:redraw()
	end
end)

-- A first launch with no file open may not know the workspace yet; the folder
-- shows up as soon as something from the project is open.
events.on("file.open", function()
	if #state.roots == 0 then
		sync_session(true)
	end
end)