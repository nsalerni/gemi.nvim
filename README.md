# Gemi.nvim

A Neovim plugin for seamless integration with Google's gemini-cli, providing an intuitive interface to interact with Gemini AI directly from your editor.

## Features

- 🚀 **Easy Installation**: Automatically installs gemini-cli and dependencies
- 🎯 **Minimal UI**: Toggleable prompt interface that stays out of your way
- 🔄 **Non-blocking Execution**: Run gemini-cli without freezing the UI (requires asyncrun.vim)
- 🔃 **Auto-reload**: Automatically reloads modified files in Neovim after gemini CLI makes changes
- 📁 **File Tracking**: Monitor and navigate files changed by Gemini
- 📊 **Diff Viewer**: Side-by-side comparison of changes made by Gemini
- 🔐 **Authentication**: Built-in Google authentication flow
- ⌨️ **Keyboard Shortcuts**: Quick access to all features

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/gemi.nvim',
  dependencies = {
    'skywind3000/asyncrun.vim', -- Optional: for non-blocking execution
  },
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
  'your-username/gemi.nvim',
  requires = {
    'skywind3000/asyncrun.vim', -- Optional: for non-blocking execution
  },
  config = function()
    require('gemi').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'skywind3000/asyncrun.vim'  " Optional: for non-blocking execution
Plug 'your-username/gemi.nvim'
```

Then in your `init.lua`:
```lua
require('gemi').setup()
```

## Quick Start

1. **Install dependencies**:
   ```vim
   :GemiInstall
   ```

2. **Authenticate with Google**:
   ```vim
   :GemiAuth
   ```

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
| `:GemiAuth` | Authenticate with Google |
| `:GemiFiles` | Show files changed by Gemi |
| `:GemiDiff` | Show diff view of changes |
| `:GemiReload` | Force reload all files changed by Gemi |

## Default Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>g` | `:GemiToggle` | Toggle Gemi prompt |
| `<leader>gf` | `:GemiFiles` | Show changed files |
| `<leader>gd` | `:GemiDiff` | Show diff view |
| `<leader>gs` | Stop execution | Stop current Gemi operation |
| `<leader>ga` | `:GemiAuth` | Authenticate with Google |
| `<leader>gi` | `:GemiInstall` | Install dependencies |
| `<leader>gr` | `:GemiReload` | Force reload changed files |

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
  },
  
  -- gemini-cli settings
  gemini = {
    model = 'gemini-pro',    -- Gemini model to use
    max_tokens = 4096,       -- Maximum tokens
    temperature = 0.7,       -- Response creativity
  },
  
  -- File tracking
  tracking = {
    auto_scan = true,        -- Automatically track file changes
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

## Requirements

- Neovim 0.8+
- Node.js 16.0+
- npm (comes with Node.js)
- Git (for file tracking)

## Authentication

On first use, Gemi will prompt you to authenticate with Google:

1. Run `:GemiAuth` or use `<leader>ga`
2. A browser window will open for Google authentication
3. Follow the Google authentication flow
4. Return to Neovim to continue

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
1. Try `:GemiAuth` to re-authenticate
2. Check if you have an active internet connection
3. Ensure you have a Google account with access to Gemini

### No File Changes Detected
The plugin tracks changes from when it starts. If you don't see changes:
1. Make sure you executed a Gemi command after installing
2. Check if files are excluded by patterns in configuration
3. Verify you're in a project directory

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Google's gemini-cli for the AI capabilities
- The Neovim community for excellent plugin development resources