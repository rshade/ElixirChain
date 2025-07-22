# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ElixirChain is a LangChain-equivalent framework built in Elixir that leverages the BEAM VM's concurrency, fault tolerance, and distributed computing capabilities to create robust AI agent systems. Currently in design phase with a comprehensive technical design document (`elixir_chain_design_doc.md`).

## Key Architecture Concepts

### Process Model
- Each agent runs as an independent GenServer process supervised by a DynamicSupervisor
- Process isolation ensures one agent failure doesn't affect others
- Automatic restart on crashes with hot code swapping support

### Core Components
1. **Agent Process**: GenServer managing conversation state, LLM routing, and tool execution
2. **Memory System**: Multiple types (conversation, semantic, episodic, working) with pluggable backends
3. **Tool System**: Behavior-based framework with async execution and streaming support
4. **Chain Engine**: Supports sequential, parallel, conditional, pipeline, and map-reduce execution

### Module Structure (planned)
```
lib/elixir_chain/
├── agent/          # Core agent GenServer and supervision
├── llm/            # LLM provider abstractions
├── memory/         # Memory management and storage
├── tools/          # Tool behavior and implementations
├── chain/          # Chain execution patterns
└── distributed/    # Multi-node coordination
```

## Development Commands

### Initial Setup
```bash
# Install all development tools and dependencies
make ensure        # Installs mise, Elixir, Erlang, PostgreSQL, Redis via mise
make setup         # Complete project setup (tools + deps + database)

# Or using mise directly
mise install       # Install all tools defined in mise.toml
mise run setup     # Run setup task
```

### Common Development Tasks
```bash
# Development workflow
make console       # Interactive shell (iex -S mix)
make test          # Run all tests
make test-watch    # Run tests in watch mode
make test-file FILE=path/to/test.exs  # Run specific test
make lint          # Run Credo linter
make format        # Format code
make format-check  # Check formatting
make dialyzer      # Type checking
make check-all     # Run all checks (format, lint, dialyzer, test)

# Database operations
make db-setup      # Create and migrate database
make db-reset      # Drop, recreate, and migrate
make db-migrate    # Run migrations
make db-console    # PostgreSQL console

# Services management (via mise)
mise run services-start   # Start PostgreSQL and Redis
mise run services-stop    # Stop services
mise run services-status  # Check service status

# Other useful commands
make docs          # Generate documentation
make deps          # Install/update dependencies
make outdated      # Check for outdated dependencies
make security      # Run security audit
make coverage      # Generate test coverage report
```

### Available Make Targets
Run `make help` to see all available commands with descriptions.

## Implementation Status

**Current State**: Design phase - no Elixir implementation exists yet. The comprehensive design document should be the primary reference.

## Key Design Decisions

1. **Concurrency First**: Every agent is a process, enabling true parallelism
2. **Fault Tolerance**: Supervision trees ensure automatic recovery
3. **Memory Flexibility**: Support for ETS, Mnesia, PostgreSQL, Redis, and vector databases
4. **Tool Safety**: JSON Schema validation, timeouts, and permission systems
5. **Streaming Support**: GenStage integration for backpressure handling

## Testing Strategy

When implementation begins:
- Mock LLM providers for deterministic unit tests
- Property-based testing for chain execution logic
- Integration tests with real LLM providers (configurable)
- Distributed testing across multiple nodes

## Configuration Approach

The project will use standard Elixir configuration:
- `config/config.exs` for compile-time configuration
- `config/runtime.exs` for runtime configuration
- Environment-specific configs (dev.exs, test.exs, prod.exs)

## Performance Targets

- Agent response time: < 2s for simple queries
- Tool execution: < 30s timeout with retry
- Memory operations: < 100ms for retrieval
- Concurrent agents: Support 1000+ active agents
- Fault recovery: < 1s from process crashes