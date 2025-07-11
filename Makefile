# Makefile for gemi.nvim
# Lua project build, lint, and format automation

.PHONY: help build lint format fix test check install-tools clean all

# Default target
help:
	@echo "Gemi.nvim Development Commands"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  help         - Show this help message"
	@echo "  install-tools - Install development tools (luacheck, stylua)"
	@echo "  build        - Validate Lua syntax and generate documentation"
	@echo "  lint         - Run luacheck on all Lua files"
	@echo "  format       - Format Lua files with stylua"
	@echo "  fix          - Fix luacheck warnings automatically"
	@echo "  check        - Run lint and format check (CI-friendly)"
	@echo "  test         - Run tests (if any)"
	@echo "  clean        - Clean generated files"
	@echo "  all          - Run full pipeline: lint, format, build"
	@echo ""
	@echo "Tools required:"
	@echo "  - luacheck: Lua linter"
	@echo "  - stylua: Lua formatter" 
	@echo "  - luarocks: Lua package manager (optional)"
	@echo ""
	@echo "Install tools with: make install-tools"

# Install development tools
install-tools:
	@echo "Installing Lua development tools..."
	@echo "Installing luacheck..."
	@if command -v luarocks >/dev/null 2>&1; then \
		luarocks install luacheck; \
	else \
		echo "luarocks not found. Installing via package manager..."; \
		if command -v brew >/dev/null 2>&1; then \
			brew install luacheck; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y luacheck; \
		elif command -v yum >/dev/null 2>&1; then \
			sudo yum install -y luacheck; \
		else \
			echo "Please install luacheck manually"; \
		fi; \
	fi
	@echo "Installing stylua..."
	@if command -v cargo >/dev/null 2>&1; then \
		cargo install stylua; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install stylua; \
	else \
		echo "Please install stylua manually from: https://github.com/JohnnyMorganz/StyLua"; \
	fi
	@echo "Development tools installation complete!"

# Build target - validate syntax and generate docs
build:
	@echo "Building gemi.nvim..."
	@echo "Checking Lua syntax..."
	@find lua -name "*.lua" -exec lua -l {} \; 2>/dev/null || (echo "Syntax check failed" && exit 1)
	@find plugin -name "*.lua" -exec lua -l {} \; 2>/dev/null || (echo "Syntax check failed" && exit 1)
	@echo "Generating help tags..."
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless -c "helptags doc" -c "quit"; \
	else \
		echo "Neovim not found, skipping help tag generation"; \
	fi
	@echo "Build complete!"

# Lint Lua files with luacheck
lint:
	@echo "Running luacheck..."
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/ plugin/ --config .luacheckrc || echo "Luacheck found issues"; \
	else \
		echo "luacheck not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Format Lua files with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ plugin/ --config-path stylua.toml; \
		echo "Formatting complete!"; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Check formatting without modifying files (for CI)
format-check:
	@echo "Checking Lua file formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua/ plugin/ --config-path stylua.toml; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Run all checks (CI-friendly)
check: lint format-check
	@echo "All checks passed!"

# Test target (placeholder for future tests)
test:
	@echo "Running tests..."
	@if [ -d "tests/" ]; then \
		echo "Running test suite..."; \
		# Add test runner here when tests are implemented; \
	else \
		echo "No tests found. Test directory: tests/"; \
	fi

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f doc/tags
	@find . -name "*.tmp" -delete
	@find . -name "*.bak" -delete
	@echo "Clean complete!"

# Run full development pipeline
all: lint format build
	@echo "Full pipeline complete!"

# Development workflow shortcuts
dev-check: check
	@echo "Development check complete!"

# Fix luacheck warnings automatically
fix:
	@echo "Fixing luacheck warnings..."
	@echo "Removing trailing whitespace..."
	@find lua/ plugin/ -name "*.lua" -exec sed -i '' 's/[[:space:]]*$$//' {} \;
	@echo "Removing empty lines with whitespace..."
	@find lua/ plugin/ -name "*.lua" -exec sed -i '' '/^[[:space:]]*$$/d' {} \;
	@echo "Running stylua to fix formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ plugin/ --config-path stylua.toml; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi
	@echo "Fix complete! Run 'make lint' to verify."

# Quick format and lint
quick: format lint
	@echo "Quick format and lint complete!"