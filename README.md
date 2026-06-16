# Gemi.nvim

[![CI](https://github.com/nsalerni/gemi.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/nsalerni/gemi.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Neovim plugin for seamless integration with Google's gemini-cli, providing an intuitive interface to interact with Gemini AI directly from your editor.

*Note: This is not an official Google product.*

## Features

- 🚀 **Easy Installation**: Automatically installs gemini-cli and dependencies
- 🎯 **Minimal UI**: Toggleable prompt interface that stays out of your way
- 🔄 **Non-blocking Execution**: Run gemini-cli without freezing the UI
- 🔃 **Auto-reload**: Automatically reloads modified files in Neovim after gemini CLI makes changes
- 📁 **File Tracking**: Monitor and navigate files changed by Gemini
- 📊 **Diff Viewer**: Side-by-side comparison of changes made by Gemini
- 🔐 **Authentication**: Seamless integration with gemini-cli authentication
- ⌨️ **Keyboard Shortcuts**: Quick access to all features

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'nsalerni/gemi.nvim',
  -- Optional: Pin to specific version
  -- tag = 'v0.1',
  config = function()
    require('gemi').setup({
      -- Optional configuration
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'nsalerni/gemi.nvim',
  -- Optional: Pin to specific version
  -- tag = 'v0.1',
  config = function()
    require('gemi').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nsalerni/gemi.nvim'
" Optional: Pin to specific version
" Plug 'nsalerni/gemi.nvim', { 'tag': 'v0.1' }
```

Then in your `init.lua`:
```lua
require('gemi').setup()
```

## Versioning

Gemi.nvim follows semantic versioning. You can:

- **Use latest**: Install without specifying a version to get the latest changes
- **Pin to version**: Use `tag = 'v0.1'` to pin to a specific stable release
- **Check version**: The current version is `0.1`

**Available versions:**
- `v0.1` - Initial release

## Quick Start

1. **Install dependencies**:
   ```vim
   :GemiInstall
   ```

2. **Authenticate with Google**:
   ```bash
   gemini
   ```
   This will open a browser window for Google authentication. Complete the flow and return to your terminal.

3. **Start using Gemi**:
   - Press `<leader>g` to open the prompt
   - Type your request and press Enter
   - Use `<leader>gf` to see changed files
   - Use `<leader>gd` to view diffs

## Commands

| Command | Description |
|---------|-------------|
| `:GemiToggle` | Toggle the Gemi prompt interface |
| `:GemiInstall` | Install gemini-cli and check dependencies |
| `:GemiFiles` | Show files changed by Gemi |
| `:GemiDiff` | Show diff view of changes |
| `:GemiReload` | Force reload all files changed by Gemi |
| `:GemiModel [model]` | Switch Gemini model (interactive menu or specify model) |
| `:GemiCurrentModel` | Show current Gemini model |

## Default Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>g` | `:GemiToggle` | Toggle Gemi prompt |
| `<leader>gf` | `:GemiFiles` | Show changed files |
| `<leader>gd` | `:GemiDiff` | Show diff view |
| `<leader>gs` | Stop execution | Stop current Gemi operation |
| `<leader>gi` | `:GemiInstall` | Install dependencies |
| `<leader>gl` | `:GemiLogs` | Show execution logs |
| `<leader>gr` | `:GemiReload` | Force reload changed files |
| `<leader>gm` | `:GemiModel` | Switch Gemini model |

## Configuration

```lua
require('gemi').setup({
  -- UI settings
  ui = {
    width = 0.8,        -- 80% of screen width
    height = 1,         -- Single line input
    position = 'bottom', -- 'bottom', 'top', or 'center'
    border = 'rounded', -- Border style
    title = ' Gemi ',   -- Window title
    prompt = 'Gemi: ',  -- Input prompt
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    toggle = '<leader>g',
    files = '<leader>gf',
    diff = '<leader>gd',
    stop = '<leader>gs',
    install = '<leader>gi',
    logs = '<leader>gl',
    reload = '<leader>gr',
    model = '<leader>gm',
  },

  -- gemini-cli settings
  gemini = {
    model = 'gemini-2.5-flash', -- Default model with better rate limits
    debug = false,               -- Enable debug mode
    all_files = false,           -- Include all files in context
    yolo = true,                 -- Automatically accept all actions
    checkpointing = true,        -- Enable checkpointing of file edits
  },

  -- File tracking
  tracking = {
    auto_scan = true,        -- Automatically track file changes
    max_files = 2000,        -- Cap project file scans
    max_file_size = 1024 * 1024, -- Skip large file contents in snapshots
    exclude_patterns = {     -- Files/patterns to ignore
      '%.git/',
      'node_modules/',
      '%.DS_Store',
      '%.log$',
    },
  },

  -- Logging
  logging = {
    debug = false,           -- Enable verbose debug logging
    level = 'INFO',          -- Log level: DEBUG, INFO, WARN, ERROR
    max_entries = 500,       -- Keep recent log entries bounded
  },

  -- Installation settings
  install = {
    check_node = true,       -- Check Node.js installation
    node_min_version = '16.0.0', -- Minimum Node.js version
    auto_install = false,    -- Auto-install dependencies
  },
})
```

## Usage Examples

### Basic Usage

1. Open the prompt with `<leader>g`
2. Type your request: "Add error handling to the login function"
3. Press Enter to execute
4. View changes with `<leader>gf` or `<leader>gd`

### File Operations

- **View changed files**: `<leader>gf` opens a quickfix list
- **Compare changes**: `<leader>gd` shows side-by-side diffs
- **Navigate to files**: Use the quickfix list to jump to changed files

### Managing Execution

- **Stop execution**: `<leader>gs` to cancel running operations
- **Hide UI while running**: Press `<Esc>` to hide the prompt (execution continues)
- **Show UI again**: `<leader>g` to toggle the prompt back on

### Debug Logging

By default, Gemi shows minimal logs (user prompts and AI responses). To enable detailed debug logging:

```lua
require('gemi').setup({
  logging = {
    debug = true,  -- Enable verbose debug logging
  },
})
```

**Debug logging includes:**
- Command execution details
- File scanning and change detection
- Buffer reload operations
- Internal state changes
- Snapshot creation process

**View logs:** Press `<leader>g` to open the overlay, or use `<leader>gl` to open logs in a separate window.

### Model Switching

Gemi supports multiple Gemini models. Switch between them easily:

**Interactive menu:**
```vim
:GemiModel
```
or press `<leader>gm`

**Direct model selection:**
```vim
:GemiModel gemini-2.5-flash    " Better rate limits, faster responses
:GemiModel gemini-2.5-pro      " More capable, slower responses
```

**Check current model:**
```vim
:GemiCurrentModel
```

**Available models:**
- `gemini-2.5-flash` (default) - Best for most use cases, better rate limits
- `gemini-2.5-pro` - More capable for complex tasks
- `gemini-1.5-flash` - Legacy fast model
- `gemini-1.5-pro` - Legacy pro model

**Automatic Rate Limit Handling:**
If you hit rate limits (error 429), Gemi automatically:
1. Switches to the alternate model (flash ↔ pro)
2. Retries your prompt with the fallback model
3. If both models fail, alerts you to wait and try again
4. Restores your original model if fallback fails

This ensures minimal interruption when hitting usage limits!

## Requirements

- Neovim 0.8+
- Node.js 16.0+
- npm (comes with Node.js)
- Git (for file tracking)

## Authentication

Before using Gemi, you need to authenticate with Google:

1. Open a terminal and run:
   ```bash
   gemini
   ```
2. A browser window will open for Google authentication
3. Follow the Google authentication flow
4. Return to your terminal to complete setup

**Note**: If you encounter authentication errors while using the plugin, you'll be prompted to run `gemini` in your terminal to re-authenticate.

## Troubleshooting

### "gemini-cli not found"
Run `:GemiInstall` to install dependencies.

### "Node.js is not installed"
Install Node.js from [nodejs.org](https://nodejs.org/) or use your package manager:
```bash
# macOS
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Authentication Issues
1. Run `gemini` in your terminal to re-authenticate
2. Check if you have an active internet connection
3. Ensure you have a Google account with access to Gemini
4. If you see "Authentication required" messages, run `gemini` in your terminal to set up authentication

### No File Changes Detected
The plugin tracks changes from when it starts. If you don't see changes:
1. Make sure you executed a Gemi command after installing
2. Check if files are excluded by patterns in configuration
3. Verify you're in a project directory

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

Run local checks with:

```bash
make check
make test
make build
```

## License

MIT License - see LICENSE file for details.
