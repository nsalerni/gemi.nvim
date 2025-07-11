-- Test the command building
local config = require('gemi.config')

-- Set up basic config
config.setup({
    gemini = {
        model = 'gemini-2.5-pro',
        debug = false,
        all_files = false,
        yolo = true,
        checkpointing = true,
    }
})

-- Build command like the executor does
local prompt = "Hello test"
local escaped_prompt = vim.fn.shellescape(prompt)
local cmd = { 'gemini', '--prompt', escaped_prompt }

local model = config.get('gemini.model')
if model then
    table.insert(cmd, '--model')
    table.insert(cmd, model)
end

local debug = config.get('gemini.debug')
if debug then
    table.insert(cmd, '--debug')
end

local all_files = config.get('gemini.all_files')
if all_files then
    table.insert(cmd, '--all_files')
end

local yolo = config.get('gemini.yolo')
if yolo then
    table.insert(cmd, '--yolo')
end

local checkpointing = config.get('gemini.checkpointing')
if checkpointing then
    table.insert(cmd, '--checkpointing')
end

print("Test command: " .. table.concat(cmd, ' '))
print("Model:", config.get('gemini.model'))
print("YOLO:", config.get('gemini.yolo'))
print("Checkpointing:", config.get('gemini.checkpointing'))