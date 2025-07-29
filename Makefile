.PHONY: help ensure setup deps compile test lint format dialyzer docs clean console release docker-build docker-run db-setup db-reset db-migrate

# mise exec command
MISE_EXEC = ~/.local/bin/mise exec --

# rebar3 path, dynamically determined to work across different environments
REBAR3 = $(shell mise exec -- which rebar3 2>/dev/null || find ~/.mix -name rebar3 2>/dev/null | head -1 || echo rebar3)

# Default target
help:
	@echo "ElixirChain Development Commands:"
	@echo ""
	@echo "Setup & Dependencies:"
	@echo "  make ensure      - Install all required development tools"
	@echo "  make setup       - Initial project setup (tools + deps + db)"
	@echo "  make deps        - Install/update Elixir dependencies"
	@echo ""
	@echo "Development:"
	@echo "  make compile     - Compile the project"
	@echo "  make console     - Start interactive Elixir shell (iex -S mix)"
	@echo "  make test        - Run all tests"
	@echo "  make test-watch  - Run tests in watch mode"
	@echo "  make lint        - Run code linter (Credo)"
	@echo "  make format      - Format code"
	@echo "  make format-check - Check code formatting"
	@echo "  make dialyzer    - Run Dialyzer for type checking"
	@echo "  make docs        - Generate documentation"
	@echo ""
	@echo "Database:"
	@echo "  make db-setup    - Create and migrate database"
	@echo "  make db-reset    - Drop, create, and migrate database"
	@echo "  make db-migrate  - Run database migrations"
	@echo ""
	@echo "Release & Deployment:"
	@echo "  make release     - Build a production release"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-run  - Run Docker container"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make check-all   - Run all checks (format, lint, dialyzer, test)"

# Install required development tools
ensure:
	@echo "==> Installing development tools..."
	@command -v mise >/dev/null 2>&1 || (echo "Installing mise..." && curl https://mise.run | sh)
	@echo "==> Activating mise..."
	@mise install
	@echo "==> Installing Hex package manager..."
	@$(MISE_EXEC) mix local.hex --force
	@echo "==> Installing Phoenix application generator..."
	@$(MISE_EXEC) mix archive.install hex phx_new --force
	@echo "==> Installing rebar3..."
	@$(MISE_EXEC) mix local.rebar --force
	@echo "==> Installing PostgreSQL client tools..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y postgresql-client; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install postgresql; \
	else \
		echo "Please install PostgreSQL client tools manually"; \
	fi
	@echo "==> Development tools installed successfully!"

# Initial project setup
setup: ensure deps db-setup
	@echo "==> Project setup complete!"

# Install/update dependencies
deps:
	@echo "==> Installing Elixir dependencies..."
	@$(MISE_EXEC) mix deps.get
	@$(MISE_EXEC) mix deps.compile

# Compile the project
compile:
	@echo "==> Compiling ElixirChain..."
	@$(MISE_EXEC) mix compile

# Run tests
test:
	@echo "==> Running tests..."
	@MIX_ENV=test MIX_REBAR3=$(REBAR3) $(MISE_EXEC) mix test

# Run tests in watch mode
test-watch:
	@echo "==> Running tests in watch mode..."
	@MIX_ENV=test $(MISE_EXEC) mix test.watch

# Run a specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test.exs"; \
	else \
		MIX_ENV=test $(MISE_EXEC) mix test $(FILE); \
	fi

# Run code linter
lint:
	@echo "==> Running Credo..."
	@$(MISE_EXEC) mix credo --strict

# Format code
format:
	@echo "==> Formatting code..."
	@$(MISE_EXEC) mix format

# Check code formatting
format-check:
	@echo "==> Checking code formatting..."
	@$(MISE_EXEC) mix format --check-formatted

# Run Dialyzer
dialyzer:
	@echo "==> Running Dialyzer..."
	@$(MISE_EXEC) mix dialyzer

# Generate documentation
docs:
	@echo "==> Generating documentation..."
	@$(MISE_EXEC) mix docs

# Clean build artifacts
clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf _build deps doc cover
	@$(MISE_EXEC) mix clean

# Start interactive console
console:
	@echo "==> Starting interactive console..."
	@$(MISE_EXEC) iex -S mix

# Create database
db-create:
	@echo "==> Creating database..."
	@$(MISE_EXEC) mix ecto.create

# Run migrations
db-migrate:
	@echo "==> Running database migrations..."
	@$(MISE_EXEC) mix ecto.migrate

# Setup database (create + migrate)
db-setup: db-create db-migrate
	@echo "==> Database setup complete!"

# Reset database
db-reset:
	@echo "==> Resetting database..."
	@$(MISE_EXEC) mix ecto.drop
	@$(MISE_EXEC) mix ecto.create
	@$(MISE_EXEC) mix ecto.migrate

# Build release
release:
	@echo "==> Building production release..."
	@MIX_ENV=prod $(MISE_EXEC) mix release

# Build Docker image
docker-build:
	@echo "==> Building Docker image..."
	@docker build -t elixir_chain:latest .

# Run Docker container
docker-run:
	@echo "==> Running Docker container..."
	@docker run -it --rm \
		-p 4000:4000 \
		-e DATABASE_URL=postgresql://postgres:postgres@host.docker.internal/elixir_chain_dev \
		elixir_chain:latest

# Run all checks
check-all: quality
	@echo "==> All checks passed!"

quality:
	@echo "==> Running quality checks..."
	@MIX_REBAR3=$(REBAR3) $(MISE_EXEC) mix quality

# Development server
server:
	@echo "==> Starting development server..."
	@$(MISE_EXEC) mix phx.server

# Generate a new migration
migration:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make migration NAME=create_users"; \
	else \
		$(MISE_EXEC) mix ecto.gen.migration $(NAME); \
	fi

# Connect to database console
db-console:
	@echo "==> Connecting to database console..."
	@$(MISE_EXEC) mix ecto.psql

# Show project information
info:
	@echo "==> Project information:"
	@$(MISE_EXEC) mix hex.info
	@echo ""
	@echo "==> Elixir version:"
	@$(MISE_EXEC) elixir --version
	@echo ""
	@echo "==> Erlang version:"
	@$(MISE_EXEC) erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

# Install git hooks
install-hooks:
	@echo "==> Installing git hooks..."
	@cp scripts/pre-commit .git/hooks/pre-commit 2>/dev/null || echo "No pre-commit hook found"
	@chmod +x .git/hooks/pre-commit 2>/dev/null || true

# Update dependencies
update-deps:
	@echo "==> Updating dependencies..."
	@$(MISE_EXEC) mix deps.update --all

# Check for outdated dependencies
outdated:
	@echo "==> Checking for outdated dependencies..."
	@$(MISE_EXEC) mix hex.outdated

# Security audit
security:
	@echo "==> Running security audit..."
	@$(MISE_EXEC) mix deps.audit

# Coverage report
coverage:
	@echo "==> Generating coverage report..."
	@MIX_ENV=test $(MISE_EXEC) mix coveralls.html
	@echo "==> Coverage report generated at cover/excoveralls.html"