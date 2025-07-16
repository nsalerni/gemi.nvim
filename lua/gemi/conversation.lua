-- lua/gemi/conversation.lua
-- Conversation history management for context preservation
local M = {}

-- Conversation state
M._state = {
	history = {}, -- Array of {role: "user"|"assistant", content: string, timestamp: string}
	max_history_length = 20, -- Maximum number of exchanges to keep
	context_enabled = true, -- Whether to include context in prompts
}

-- Add a user message to the conversation history
function M.add_user_message(prompt)
	if not M._state.context_enabled then
		return
	end
	table.insert(M._state.history, {
		role = "user",
		content = prompt,
		timestamp = os.date("%H:%M:%S")
	})
	-- Trim history if it gets too long
	M._trim_history()
end

-- Add an assistant response to the conversation history
function M.add_assistant_response(response)
	if not M._state.context_enabled then
		return
	end
	table.insert(M._state.history, {
		role = "assistant",
		content = response,
		timestamp = os.date("%H:%M:%S")
	})
	-- Trim history if it gets too long
	M._trim_history()
end

-- Trim conversation history to stay within limits
function M._trim_history()
	while #M._state.history > M._state.max_history_length do
		table.remove(M._state.history, 1)
	end
end

-- Build context prompt that includes conversation history
function M.build_context_prompt(new_prompt)
	if not M._state.context_enabled or #M._state.history == 0 then
		return new_prompt
	end
	local context_parts = {}
	table.insert(context_parts, "Previous conversation:")
	-- Add conversation history
	for _, entry in ipairs(M._state.history) do
		if entry.role == "user" then
			table.insert(context_parts, "User: " .. entry.content)
		else
			table.insert(context_parts, "Assistant: " .. entry.content)
		end
	end
	table.insert(context_parts, "")
	table.insert(context_parts, "Current prompt:")
	table.insert(context_parts, new_prompt)
	return table.concat(context_parts, "\n")
end

-- Clear conversation history
function M.clear_history()
	M._state.history = {}
	local logger = require("gemi.logger")
	logger.info("Conversation history cleared")
	-- Auto-refresh overlay if visible
	vim.schedule(function()
		local ok, overlay = pcall(require, "gemi.overlay")
		if ok then
			overlay.auto_refresh()
		end
	end)
end

-- Get conversation history
function M.get_history()
	return M._state.history
end

-- Get conversation history count
function M.get_history_count()
	return #M._state.history
end

-- Toggle context preservation
function M.toggle_context()
	M._state.context_enabled = not M._state.context_enabled
	local logger = require("gemi.logger")
	local status = M._state.context_enabled and "enabled" or "disabled"
	logger.info("Conversation context " .. status)
	-- Auto-refresh overlay if visible
	vim.schedule(function()
		local ok, overlay = pcall(require, "gemi.overlay")
		if ok then
			overlay.auto_refresh()
		end
	end)
	return M._state.context_enabled
end

-- Check if context is enabled
function M.is_context_enabled()
	return M._state.context_enabled
end

-- Set maximum history length
function M.set_max_history_length(length)
	M._state.max_history_length = math.max(1, length)
	M._trim_history()
end

-- Get maximum history length
function M.get_max_history_length()
	return M._state.max_history_length
end

-- Get conversation summary for display
function M.get_conversation_summary()
	if #M._state.history == 0 then
		return "No conversation history"
	end
	local summary = {}
	for i, entry in ipairs(M._state.history) do
		local role_prefix = entry.role == "user" and "Q" or "A"
		local preview = entry.content:sub(1, 50)
		if #entry.content > 50 then
			preview = preview .. "..."
		end
		table.insert(summary, string.format("%d. [%s] %s: %s", i, entry.timestamp, role_prefix, preview))
	end
	return table.concat(summary, "\n")
end

return M