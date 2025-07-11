-- lua/gemi/installer.lua
-- Installation and dependency checking
local M = {}
local config = require("gemi.config")
-- Check if a command exists
local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if handle then
    local result = handle:read("*l")
    handle:close()
    return result ~= nil and result ~= ""
  end
  return false
end
-- Get Node.js version
local function get_node_version()
  local handle = io.popen("node --version 2>/dev/null")
  if handle then
    local version = handle:read("*l")
    handle:close()
    if version then
      return version:gsub("^v", "") -- Remove 'v' prefix
    end
  end
  return nil
end
-- Compare version strings
local function version_compare(v1, v2)
  local function normalize(v)
    local parts = {}
    for part in v:gmatch("[^%.]+") do
      table.insert(parts, tonumber(part) or 0)
    end
    return parts
  end
  local parts1 = normalize(v1)
  local parts2 = normalize(v2)
  for i = 1, math.max(#parts1, #parts2) do
    local p1 = parts1[i] or 0
    local p2 = parts2[i] or 0
    if p1 > p2 then
      return 1
    end
    if p1 < p2 then
      return -1
    end
  end
  return 0
end
-- Check Node.js installation
function M.check_node()
  if not command_exists("node") then
    return false, "Node.js is not installed"
  end
  local version = get_node_version()
  if not version then
    return false, "Could not determine Node.js version"
  end
  local min_version = config.get("install.node_min_version")
  if version_compare(version, min_version) < 0 then
    return false, string.format("Node.js version %s is required (found %s)", min_version, version)
  end
  return true, version
end
-- Check npm installation
function M.check_npm()
  if not command_exists("npm") then
    return false, "npm is not installed"
  end
  return true, "npm is available"
end
-- Check gemini-cli installation
function M.check_gemini_cli()
  if not command_exists("gemini") then
    return false, "gemini-cli is not installed"
  end
  return true, "gemini-cli is available"
end
-- Install Node.js (guide user)
function M.install_node()
  local message = [[
Node.js is required but not installed. Please install Node.js:
macOS:
  brew install node
  or download from: https://nodejs.org/
Linux:
  # Ubuntu/Debian
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
  # Fedora
  sudo dnf install nodejs npm
Windows:
  Download from: https://nodejs.org/
]]
  vim.notify(message, vim.log.levels.INFO)
  return false
end
-- Install gemini-cli
function M.install_gemini_cli()
  vim.notify("Installing @google/gemini-cli...", vim.log.levels.INFO)
  local job = vim.fn.jobstart("npm install -g @google/gemini-cli", {
    on_stdout = function(_, data)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("npm: " .. line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("npm error: " .. line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("gemini-cli installed successfully!", vim.log.levels.INFO)
      else
        vim.notify("Failed to install gemini-cli (exit code: " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
  return job ~= 0
end
-- Install all dependencies
function M.install_dependencies()
  vim.notify("Checking dependencies...", vim.log.levels.INFO)
  -- Check Node.js
  local node_ok, node_msg = M.check_node()
  if not node_ok then
    vim.notify("Node.js check failed: " .. node_msg, vim.log.levels.ERROR)
    M.install_node()
    return
  end
  vim.notify("Node.js: " .. node_msg, vim.log.levels.INFO)
  -- Check npm
  local npm_ok, npm_msg = M.check_npm()
  if not npm_ok then
    vim.notify("npm check failed: " .. npm_msg, vim.log.levels.ERROR)
    return
  end
  vim.notify("npm: " .. npm_msg, vim.log.levels.INFO)
  -- Check gemini-cli
  local gemini_ok, gemini_msg = M.check_gemini_cli()
  if not gemini_ok then
    vim.notify("gemini-cli not found, installing...", vim.log.levels.INFO)
    M.install_gemini_cli()
  else
    vim.notify("gemini-cli: " .. gemini_msg, vim.log.levels.INFO)
    vim.notify("All dependencies are ready!", vim.log.levels.INFO)
  end
end
-- Check all dependencies
function M.check_all_dependencies()
  local issues = {}
  local node_ok, node_msg = M.check_node()
  if not node_ok then
    table.insert(issues, "Node.js: " .. node_msg)
  end
  local npm_ok, npm_msg = M.check_npm()
  if not npm_ok then
    table.insert(issues, "npm: " .. npm_msg)
  end
  local gemini_ok, gemini_msg = M.check_gemini_cli()
  if not gemini_ok then
    table.insert(issues, "gemini-cli: " .. gemini_msg)
  end
  return #issues == 0, issues
end
return M
