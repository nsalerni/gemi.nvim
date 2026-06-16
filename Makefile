# Makefile for gemi.nvim
# Lua project build, lint, and format automation

.PHONY: help build lint format fix test check install-tools clean all version release bun-help

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
	@echo "  version      - Show current version"
	@echo "  release      - Create release package"
	@echo "  all          - Run full pipeline: lint, format, build"
	@echo ""
	@echo "Bun.js commands (faster runtime):"
	@echo "  bun-dev      - Development mode with file watching"
	@echo "  bun-build    - Build using bun runtime"
	@echo "  bun-lint     - Lint using bun runtime"
	@echo "  bun-format   - Format using bun runtime"
	@echo "  bun-check    - Check using bun runtime"
	@echo "  bun-test     - Test using bun runtime"
	@echo "  bun-install  - Install tools using bun"
	@echo ""
	@echo "Tools required:"
	@echo "  - luacheck: Lua linter"
	@echo "  - stylua: Lua formatter" 
	@echo "  - luarocks: Lua package manager (optional)"
	@echo "  - bun: Fast JavaScript runtime (optional, for better performance)"
	@echo ""
	@echo "Install tools with: make install-tools or make bun-install"

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
	@find lua plugin tests -name "*.lua" -exec luac -p {} \; || (echo "Syntax check failed" && exit 1)
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
		luacheck lua/ plugin/ tests/ --config .luacheckrc || (echo "Luacheck found issues" && exit 1); \
	else \
		echo "luacheck not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Format Lua files with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ plugin/ tests/ --config-path stylua.toml; \
		echo "Formatting complete!"; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Check formatting without modifying files (for CI)
format-check:
	@echo "Checking Lua file formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua/ plugin/ tests/ --config-path stylua.toml; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi

# Run all checks (CI-friendly)
check: lint format-check
	@echo "All checks passed!"

# Run headless Neovim tests
test:
	@echo "Running headless Neovim tests..."
	@nvim --headless -u NONE -n --cmd "set runtimepath^=$(CURDIR)" -l tests/run.lua

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
	@find lua/ plugin/ tests/ -name "*.lua" -exec sed -i.bak 's/[[:space:]]*$$//' {} \;
	@find lua/ plugin/ tests/ -name "*.lua" -exec sed -i.bak '/^[[:space:]]*$$/d' {} \;
	@find lua/ plugin/ tests/ -name "*.lua.bak" -delete
	@echo "Running stylua to fix formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ plugin/ tests/ --config-path stylua.toml; \
	else \
		echo "stylua not found. Install with: make install-tools"; \
		exit 1; \
	fi
	@echo "Fix complete! Run 'make lint' to verify."

# Quick format and lint
quick: format lint
	@echo "Quick format and lint complete!"

# Show current version
version:
	@cat VERSION

# Create release package
release:
	@echo "Creating release build..."
	@VERSION=$$(cat VERSION); \
	echo "Building version $$VERSION"; \
	mkdir -p dist; \
	tar -czf dist/gemi.nvim-$$VERSION.tar.gz \
		--exclude='.git*' \
		--exclude='dist' \
		--exclude='node_modules' \
		--exclude='*.log' \
		--exclude='tests' \
		--exclude='.DS_Store' \
		--exclude='Makefile' \
		--exclude='.github' \
		.; \
	echo "Release package created: dist/gemi.nvim-$$VERSION.tar.gz"

# Bun.js powered commands for faster development
bun-dev:
	@if command -v bun >/dev/null 2>&1; then \
		bun run dev; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-build:
	@if command -v bun >/dev/null 2>&1; then \
		bun run build; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-lint:
	@if command -v bun >/dev/null 2>&1; then \
		bun run lint; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-format:
	@if command -v bun >/dev/null 2>&1; then \
		bun run format; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-check:
	@if command -v bun >/dev/null 2>&1; then \
		bun run check; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-test:
	@if command -v bun >/dev/null 2>&1; then \
		bun run test; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-install:
	@if command -v bun >/dev/null 2>&1; then \
		echo "Installing dependencies with bun..."; \
		bun install; \
		bun run install-tools; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi

bun-clean:
	@if command -v bun >/dev/null 2>&1; then \
		bun run clean; \
	else \
		echo "Bun not found. Install from: https://bun.sh"; \
		exit 1; \
	fi
