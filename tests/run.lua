local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local tests = {}

local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

local function reset_gemi_modules()
	for name, _ in pairs(package.loaded) do
		if name == "gemi" or name:match("^gemi%.") then
			package.loaded[name] = nil
		end
	end

	vim.g.loaded_gemi = nil
	pcall(vim.api.nvim_del_augroup_by_name, "gemi_auto_reload")
	pcall(vim.api.nvim_del_augroup_by_name, "gemi_asyncrun")
end

local function assert_eq(actual, expected, message)
	if actual ~= expected then
		error(
			string.format(
				"%s\nexpected: %s\nactual:   %s",
				message or "values differ",
				vim.inspect(expected),
				vim.inspect(actual)
			)
		)
	end
end

local function assert_truthy(value, message)
	if not value then
		error(message or "expected truthy value")
	end
end

local function count_occurrences(text, needle)
	local count = 0
	local start = 1
	while true do
		local found = text:find(needle, start, true)
		if not found then
			break
		end
		count = count + 1
		start = found + #needle
	end
	return count
end

test("plugin loader registers real commands idempotently", function()
	reset_gemi_modules()

	vim.cmd("runtime plugin/gemi.lua")
	require("gemi.commands").setup()
	require("gemi.commands").setup()

	assert_eq(vim.fn.exists(":GemiToggle"), 2, "GemiToggle should be registered")
	assert_eq(vim.fn.exists(":GemiTest"), 0, "test-only plugin command should not be registered")

	local ok, err = pcall(function()
		require("gemi").setup({ tracking = { auto_scan = false }, keymaps = false })
	end)
	assert_truthy(ok, err)
end)

test("setup applies and clears configured keymaps", function()
	reset_gemi_modules()

	local gemi = require("gemi")
	gemi.setup({
		tracking = { auto_scan = false },
		keymaps = { toggle = "<leader>x" },
	})

	assert_truthy(vim.fn.maparg("<leader>x", "n") ~= "", "configured keymap should be set")

	gemi.setup({ tracking = { auto_scan = false }, keymaps = false })
	assert_eq(vim.fn.maparg("<leader>x", "n"), "", "plugin keymap should be cleared")
end)

test("executor builds argv without shell escaping prompts", function()
	reset_gemi_modules()

	local config = require("gemi.config")
	config.setup({
		gemini = {
			model = "gemini-2.5-pro",
			debug = true,
			all_files = true,
			yolo = false,
			checkpointing = true,
		},
	})

	local prompt = "hello 'world'\nnext line"
	local cmd = require("gemi.executor")._build_command(prompt)

	assert_eq(cmd[1], "gemini")
	assert_eq(cmd[2], "--prompt")
	assert_eq(cmd[3], prompt, "prompt should remain a raw argv item")
	assert_truthy(vim.tbl_contains(cmd, "--debug"), "debug flag should be present")
	assert_truthy(vim.tbl_contains(cmd, "--all_files"), "all_files flag should be present")
	assert_truthy(vim.tbl_contains(cmd, "--checkpointing"), "checkpointing flag should be present")
	assert_truthy(not vim.tbl_contains(cmd, "--yolo"), "false yolo flag should be omitted")
end)

test("execute_prompt builds context before adding current user message", function()
	reset_gemi_modules()

	local captured_prompts = {}
	package.loaded["gemi.executor"] = {
		run_gemini = function(prompt, callback)
			table.insert(captured_prompts, prompt)
			callback(true, "assistant response")
			return { shutdown = function() end }
		end,
	}
	package.loaded["gemi.tracker"] = {
		setup = function() end,
		create_snapshot = function() end,
		scan_for_changes = function() end,
	}

	local gemi = require("gemi")
	gemi.setup({ tracking = { auto_scan = false }, keymaps = false })

	gemi.execute_prompt("first task")
	gemi.execute_prompt("second task")

	assert_eq(captured_prompts[1], "first task")
	assert_truthy(captured_prompts[2]:find("Previous conversation:", 1, true), "second prompt should include history")
	assert_eq(count_occurrences(captured_prompts[2], "Current prompt:\nsecond task"), 1)
	assert_eq(count_occurrences(captured_prompts[2], "User: second task"), 0, "current prompt should not be duplicated")
end)

test("snapshot stores metadata by default without reading file content", function()
	reset_gemi_modules()

	local config = require("gemi.config")
	config.setup({ tracking = { auto_scan = false, store_snapshot_content = false } })
	local tracker = require("gemi.tracker")

	local tmpdir = vim.fn.tempname()
	vim.fn.mkdir(tmpdir, "p")
	local test_file = tmpdir .. "/tracked.txt"
	vim.fn.writefile({ "snapshot content" }, test_file)

	local old_cwd = vim.fn.getcwd()
	vim.cmd("cd " .. vim.fn.fnameescape(tmpdir))

	local snapshot = tracker.create_snapshot("test")
	local stored = nil
	for path, state in pairs(snapshot.files) do
		if path:find("tracked.txt", 1, true) then
			stored = state
			break
		end
	end

	assert_truthy(stored, "snapshot should include tracked file")
	assert_eq(stored.content, nil, "metadata-only snapshot should not store file content")
	assert_truthy(stored.mtime ~= nil)
	assert_truthy(stored.size > 0)

	vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
	vim.fn.delete(tmpdir, "rf")
end)

test("tracker picks latest snapshot by sequence", function()
	reset_gemi_modules()

	local config = require("gemi.config")
	config.setup({ tracking = { auto_scan = false } })

	local tracker = require("gemi.tracker")
	tracker._state.snapshots = {
		first = { sequence = 1, timestamp = 100 },
		second = { sequence = 2, timestamp = 100 },
	}

	assert_eq(tracker._get_latest_snapshot(), tracker._state.snapshots.second)
end)

test("tracker reload only matches exact paths and preserves modified buffers", function()
	reset_gemi_modules()

	local config = require("gemi.config")
	config.setup({ tracking = { auto_scan = false } })
	local tracker = require("gemi.tracker")

	local tmpdir = vim.fn.tempname()
	vim.fn.mkdir(tmpdir .. "/a", "p")
	vim.fn.mkdir(tmpdir .. "/b", "p")

	local open_file = tmpdir .. "/a/file.txt"
	local changed_file = tmpdir .. "/b/file.txt"
	vim.fn.writefile({ "original" }, open_file)
	vim.fn.writefile({ "changed" }, changed_file)

	vim.cmd("edit " .. vim.fn.fnameescape(open_file))
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved" })
	vim.api.nvim_buf_set_option(buf, "modified", true)

	tracker.auto_reload_changed_files({
		{ file = changed_file, type = "modified" },
	})
	vim.wait(50)

	assert_eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "unsaved")
	assert_truthy(vim.api.nvim_buf_get_option(buf, "modified"), "unrelated modified buffer should stay modified")

	vim.cmd("bwipeout!")
	vim.fn.delete(tmpdir, "rf")
end)

test("setup honors conversation and logging configuration", function()
	reset_gemi_modules()

	local gemi = require("gemi")
	gemi.setup({
		tracking = { auto_scan = false },
		keymaps = false,
		conversation = { max_history_length = 3 },
		logging = { level = "ERROR", max_entries = 10 },
	})

	local conversation = require("gemi.conversation")
	assert_eq(conversation.get_max_history_length(), 3)

	local logger = require("gemi.logger")
	logger.info("filtered info")
	logger.error("kept error")
	assert_eq(#logger.get_logs(), 1)
	assert_eq(logger.get_logs()[1].message, "kept error")
end)

test("logger trims stored entries and coalesces refresh scheduling", function()
	reset_gemi_modules()

	local config = require("gemi.config")
	config.setup({ logging = { max_entries = 2 } })
	local logger = require("gemi.logger")

	logger.info("one")
	logger.info("two")
	logger.info("three")

	assert_eq(#logger.get_logs(), 2)
	assert_eq(logger.get_logs()[1].message, "two")
	assert_eq(logger.get_logs()[2].message, "three")
	vim.wait(20)
end)

test("toggle reopens overlay after closing via overlay hide", function()
	reset_gemi_modules()

	local gemi = require("gemi")
	gemi.setup({ tracking = { auto_scan = false }, keymaps = false })
	local overlay = require("gemi.overlay")

	gemi.show()
	overlay.hide()
	assert_truthy(not overlay.is_visible(), "overlay should be hidden after direct hide")

	gemi.toggle()
	assert_truthy(overlay.is_visible(), "toggle should reopen overlay after direct hide")
	overlay.hide()
end)

test("failed execute_prompt does not add user message to conversation", function()
	reset_gemi_modules()

	package.loaded["gemi.executor"] = {
		run_gemini = function(prompt, callback)
			if prompt:find("fail task", 1, true) then
				callback(false, "execution failed")
			else
				callback(true, "assistant response")
			end
			return { shutdown = function() end }
		end,
	}
	package.loaded["gemi.tracker"] = {
		setup = function() end,
		create_snapshot = function() end,
		scan_for_changes = function() end,
	}

	local gemi = require("gemi")
	gemi.setup({ tracking = { auto_scan = false }, keymaps = false })

	gemi.execute_prompt("first task")
	gemi.execute_prompt("fail task")

	local history = require("gemi.conversation").get_history()
	assert_eq(#history, 2, "only successful exchange should be stored")
	assert_eq(history[1].content, "first task")
	assert_eq(history[2].content, "assistant response")
end)

test("executor auth detection avoids generic false positives", function()
	reset_gemi_modules()

	local executor = require("gemi.executor")

	assert_truthy(executor._is_auth_error("Authentication required for this request"))
	assert_truthy(executor._is_auth_error("Please log in to continue"))
	assert_truthy(not executor._is_auth_error("authority file not found"))
	assert_truthy(not executor._is_auth_error("author updated the document"))
end)

test("overlay can show, update, and hide without stale scheduled window errors", function()
	reset_gemi_modules()

	require("gemi").setup({ tracking = { auto_scan = false }, keymaps = false })
	local overlay = require("gemi.overlay")

	overlay.show()
	overlay.update_logs()
	overlay.add_model_indicator()
	overlay.hide()
	vim.wait(20)

	assert_truthy(not overlay.is_visible(), "overlay should be hidden")
end)

local failures = {}

for _, item in ipairs(tests) do
	local ok, err = pcall(item.fn)
	if ok then
		print("PASS " .. item.name)
	else
		table.insert(failures, { name = item.name, err = err })
		print("FAIL " .. item.name)
		print(err)
	end
end

if #failures > 0 then
	print(string.format("%d/%d tests failed", #failures, #tests))
	vim.cmd("cquit")
else
	print(string.format("%d tests passed", #tests))
	vim.cmd("qa")
end
