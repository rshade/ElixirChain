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

## Hybrid Elixir/Erlang Architecture

ElixirChain is built **Elixir-first** with the flexibility to leverage Erlang components when enhanced reliability is needed. We always lean towards writing Elixir code first, but maintain dependencies and architecture that allow strategic use of Erlang's battle-tested libraries.

### Strategic Use of Erlang Components

```elixir
# Core agent in Elixir for developer experience
defmodule ElixirChain.Agent do
  use GenServer
  
  # But leverage Erlang's robust networking
  def start_distributed_agent(node_name) do
    :rpc.call(node_name, __MODULE__, :start_link, [])
  end
  
  # Use Erlang's mature HTTP client for reliability
  defp make_llm_request(url, body, headers) do
    :httpc.request(:post, {url, headers, "application/json", body}, 
                   [{:timeout, 60_000}], [])
  end
end
```

### Where Erlang Components Shine

1. **Networking Stack**: Use `:gen_tcp`, `:ssl`, and `:httpc` for rock-solid network operations
2. **Distributed Computing**: Leverage `:global`, `:pg`, and `:rpc` for cluster coordination
3. **System Monitoring**: Use `:observer`, `:sys`, and `:appmon` for deep system introspection
4. **Telecom Protocols**: If needed - SNMP, ASN.1, or other telecom standards
5. **Time and Scheduling**: `:timer` module for precise timing operations

### Hybrid Architecture Example

```elixir
defmodule ElixirChain.NetworkLayer do
  @moduledoc """
  Wraps Erlang's battle-tested networking with Elixir conveniences
  """
  
  # Elixir's nice API wrapping Erlang's robust implementation
  def make_request(url, options \\ []) do
    timeout = Keyword.get(options, :timeout, 30_000)
    headers = Keyword.get(options, :headers, [])
    
    # Use Erlang's httpc for maximum reliability
    case :httpc.request(:get, {url, headers}, [{:timeout, timeout}], []) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        {:ok, body}
      {:ok, {{_version, status, _reason}, _headers, body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end

defmodule ElixirChain.ClusterManager do
  @moduledoc """
  Distributed agent coordination using Erlang's proven clustering
  """
  
  # Elixir GenServer with Erlang clustering underneath
  use GenServer
  
  def join_cluster(nodes) when is_list(nodes) do
    # Use Erlang's built-in clustering
    Enum.each(nodes, &:net_kernel.connect_node/1)
    
    # Register with Erlang's global registry
    :global.register_name(__MODULE__, self())
  end
  
  def find_agent_on_cluster(agent_id) do
    # Leverage Erlang's global process registry
    case :global.whereis_name({:agent, agent_id}) do
      :undefined -> {:error, :not_found}
      pid -> {:ok, pid}
    end
  end
end
```

### Best of Both Worlds Integration

```elixir
# mix.exs - Include both ecosystems
defp deps do
  [
    # Elixir ecosystem goodness
    {:phoenix, "~> 1.7"},
    {:jason, "~> 1.4"},
    {:ecto, "~> 3.10"},
    
    # Direct Erlang dependencies for specialized needs
    {:observer_cli, "~> 1.7"},  # Better than :observer
    {:recon, "~> 2.5"},         # Production debugging
    {:lager, "~> 3.9"},         # Industrial-strength logging
    {:ranch, "~> 2.1"},         # Socket acceptor pool
    
    # Elixir wrappers around Erlang libraries
    {:gen_state_machine, "~> 3.0"}, # :gen_statem wrapper
    {:poolboy, "~> 1.5"}             # Connection pooling
  ]
end
```

### Framework Design with Hybrid Benefits

- **API Layer**: Pure Elixir for developer experience
- **Core Logic**: Elixir for readability and maintainability  
- **Network Operations**: Erlang's `:httpc`, `:gen_tcp` for reliability
- **Clustering**: Erlang's `:global`, `:pg` for proven distributed coordination
- **Monitoring**: Erlang's `:observer` tools for deep system insight
- **Hot Code Loading**: Both languages support it, use Erlang's proven patterns

### Practical Benefits Example

```elixir
defmodule ElixirChain.SupervisedAgent do
  # Elixir's nice supervisor syntax
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Elixir agent for business logic
      {ElixirChain.Agent, []},
      
      # Erlang-based network pool for reliability
      :poolboy.child_spec(:http_pool, [
        name: {:local, :http_pool},
        worker_module: ElixirChain.HttpWorker,
        size: 10,
        max_overflow: 20
      ])
    ]
    
    # Use Erlang's proven supervision strategies
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10)
  end
end
```

### Why This Hybrid Approach Wins

1. **Developer Experience**: Elixir's syntax and tooling for 90% of development
2. **Battle-Tested Reliability**: Erlang's proven libraries for critical infrastructure
3. **Performance**: No overhead - both compile to identical BEAM bytecode
4. **Ecosystem Access**: Full access to both package repositories
5. **Future-Proof**: Can gradually migrate between languages as needed
6. **Team Flexibility**: Erlang experts can contribute in their preferred language

### Development Philosophy

**Always write Elixir first.** Only consider Erlang components when:
- Specific reliability requirements aren't met by existing Elixir solutions
- Battle-tested Erlang libraries provide significant stability advantages
- Performance profiling indicates a need for low-level optimizations

The architecture is designed to make adding Erlang components seamless when needed, but the default approach should always be pure Elixir for maintainability and consistency.

## Technical Expertise and Best Practices

### Core BEAM VM Patterns

#### Use BEAM VM Strengths
- **Prefer GenServer over Agent** for stateful components (better introspection)
- **Always use Supervisor trees** - never start processes directly
- **Leverage pattern matching** extensively in function heads and case statements
- **Use message passing** over shared state (ETS exceptions noted below)
- **Implement circuit breakers** using GenServer state for external API calls
- **Design for hot code swapping** - avoid persistent state in module attributes

#### OTP Design Patterns
```elixir
# Prefer this pattern for core components
defmodule ElixirChain.ComponentSupervisor do
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      {ElixirChain.Component, []},
      {ElixirChain.ComponentRegistry, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Memory and State Management
- **Use ETS for**: High-frequency lookups, caching, shared read-heavy data
- **Use GenServer state for**: Process-specific state, complex state machines
- **Use Mnesia for**: Distributed persistent state, complex queries
- **Avoid GenServer state for**: Large data structures (use ETS + pid reference)

### Error Handling Philosophy
- **Let it crash**: Don't defensively program - use supervisors
- **Fail fast**: Validate inputs early, crash on invalid state
- **Isolate failures**: Each agent/component in separate process
- **Use EXIT signals**: Link processes that should fail together

### Concurrency Patterns
- **Spawn processes liberally** - BEAM handles millions efficiently
- **Use Task.async/await** for parallel operations with timeouts
- **Implement backpressure** with GenStage for data pipelines
- **Pool connections** to external services (HTTP, DB)

### Memory Management
```elixir
# Prefer streaming over loading large datasets
def process_large_dataset(source) do
  source
  |> Stream.chunk_every(1000)
  |> Stream.map(&process_chunk/1)
  |> Stream.run()
end
```

### ETS Usage Patterns
```elixir
# For caches and lookups
:ets.new(:my_cache, [:set, :public, :named_table, 
                     {:read_concurrency, true}])

# For process registries  
:ets.new(:process_registry, [:set, :public, :named_table,
                            {:write_concurrency, true}])
```

## Testing Strategies

### Unit Testing
- **Test behaviors, not implementations** - focus on message contracts
- **Use process isolation** - each test gets fresh processes
- **Mock external services** with dedicated GenServer mocks
- **Test supervisor restart logic** explicitly

### Integration Testing
```elixir
# Test full supervision trees
test "agent supervisor restarts failed agents" do
  {:ok, supervisor} = AgentSupervisor.start_link([])
  {:ok, agent} = AgentSupervisor.start_agent(supervisor, %{})
  
  # Kill the agent
  Process.exit(agent, :kill)
  
  # Verify supervisor restarted it
  assert_receive {:agent_restarted, _new_pid}, 1000
end
```

### Property-Based Testing
Use StreamData for:
- Message format validation
- State machine transitions
- Concurrent operation safety

## Preferred Libraries
- **HTTP clients**: Finch (connection pooling) or HTTPoison (simple)
- **JSON**: Jason (performance)
- **Database**: Ecto with PostgreSQL
- **Caching**: Cachex or direct ETS
- **Testing**: ExUnit + StreamData + Mox
- **Observability**: Telemetry + TelemetryMetrics

## Avoid These Patterns
- **Heavy use of Agent** - use GenServer for better debugging
- **Synchronous GenServer calls in loops** - causes cascading timeouts
- **Large GenServer state** - move to ETS if > 1MB
- **Process.sleep/1** - use :timer.sleep/1 or receive with timeout

## Hot Code Updates
```elixir
# Design modules for hot swapping
defmodule ElixirChain.Agent do
  use GenServer
  
  # Always include version in state
  defstruct [:version, :data]
  
  def code_change(_old_vsn, state, _extra) do
    {:ok, %{state | version: "1.1.0"}}
  end
end
```

## Documentation Standards
```elixir
defmodule ElixirChain.Agent do
  @moduledoc """
  Manages AI agent lifecycle and conversation state.
  
  ## Usage
  
      {:ok, agent} = ElixirChain.Agent.start_link(%{name: "assistant"})
      {:ok, response} = ElixirChain.Agent.chat(agent, "Hello")
      
  ## State Management
  
  Agent state is isolated per process. Memory is managed through
  separate Memory GenServer to avoid blocking agent operations.
  """
  
  @typedoc "Agent configuration options"
  @type config :: %{
    name: String.t(),
    llm_provider: module(),
    tools: [module()]
  }
end
```

## REPL Development
```elixir
# Start with application
iex -S mix

# Useful introspection commands
:observer.start()              # GUI process observer
:recon.proc_count(:memory)     # Memory usage by process
:sys.get_state(pid)           # Inspect GenServer state
```

## Security Considerations
- **Validate all external inputs** before pattern matching
- **Limit process spawning** from user input
- **Use secure random** for session tokens: `:crypto.strong_rand_bytes/1`
- **Sanitize tool inputs** before execution
- **Implement rate limiting** at GenServer level

## Claude's Guidance
- **CRITICAL**: Always think systematically.