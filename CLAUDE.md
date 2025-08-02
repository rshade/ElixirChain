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

## Strategic Decisions & Project Direction

### LLM Provider Strategy
**Primary Focus: Google Gemini** - As of July 2025, project direction prioritizes Gemini as the MVP LLM provider:

**Strategic Reasons:**
- **Massive Context Window**: 2M tokens enables simplified agent architecture
- **Public API Access**: Well-documented, accessible for open-source development
- **Multimodal Capabilities**: Future-ready for text, image, document processing
- **Cost Effectiveness**: Excellent price-to-performance ratio for large context workloads
- **Agent Architecture Alignment**: Large context reduces need for complex memory management

**Implementation Approach:**
- Gemini as primary/reference implementation in design phase
- Maintain extensible architecture for future providers (OpenAI, Anthropic, local models)
- Leverage 2M token context to simplify initial memory system design
- Plan for multimodal tool integration (images, documents, rich media)

### Documentation Strategy
**Hybrid Approach** for API examples and documentation:

**README.md Content:**
- High-level usage patterns and inspiring examples
- Basic configuration showing Gemini integration
- Simple multi-agent coordination examples
- Focus on "what" ElixirChain can do

**Detailed Documentation (future):**
- Step-by-step implementation guides
- Authentication, error handling, rate limiting
- Advanced tool integration patterns
- Production deployment and scaling

**Principle**: README as "product demo", detailed docs as "implementation guide"

### Architecture Insights
**Key Learnings from Design Phase:**

1. **Actor Model + Large Context = Simplified Architecture**
   - Gemini's 2M tokens reduces need for complex conversation compression
   - Process isolation + large context = powerful agent coordination
   - Less memory management complexity in initial implementation

2. **BEAM VM Strengths for AI Agents**
   - Process-per-agent model scales naturally
   - Supervision trees provide automatic fault recovery
   - Hot code swapping enables runtime agent updates
   - Built-in distribution supports multi-node agent systems

3. **Tool System Design**
   - JSON Schema validation for security
   - Async execution with timeout handling
   - Multimodal return types for Gemini integration
   - Permission systems for secure tool access

## Claude Code Configuration

### Specialized Agents
ElixirChain uses specialized AI agents for different development contexts, stored in the `.claude/agents/` directory:

#### Core Development Agents
- **`code-reviewer.md`** - Expert code review with ElixirChain-specific patterns, BEAM VM optimization, and AI agent architecture validation
- **`elixir-ai-agent-engineer.md`** - Elite Elixir engineer specializing in AI agent systems, OTP patterns, and fault-tolerant architectures

#### Architecture & Coordination Agents  
- **`distributed-systems-architect.md`** - Expert in distributed BEAM VM clusters, multi-node coordination, and scalable agent architectures
- **`multi-agent-coordinator.md`** - Specialist in agent team formation, coordination patterns, consensus algorithms, and workflow orchestration
- **`performance-optimizer.md`** - Expert in BEAM VM performance, memory optimization, latency reduction, and scaling to 1000+ concurrent agents

#### Agent Usage Patterns
- **Use `elixir-ai-agent-engineer`** for core framework implementation, GenServer design, LLM integration, and OTP patterns
- **Use `code-reviewer`** for comprehensive code quality analysis with ElixirChain-specific architectural validation
- **Use `distributed-systems-architect`** for multi-node scaling, cluster coordination, and distributed state management
- **Use `multi-agent-coordinator`** for designing agent team structures, coordination workflows, and consensus mechanisms
- **Use `performance-optimizer`** for system profiling, memory optimization, and scaling performance improvements

### Configuration Files
- `settings.local.json` - Claude-specific permissions and local configuration

### Agent Development Insights

#### Multi-Agent Coordination Patterns
From analyzing successful AI agent frameworks and ElixirChain's unique BEAM VM advantages:
- **Session Persistence is Critical**: Agents must survive crashes with full context recovery (differentiator from Python frameworks)
- **Multi-Agent Communication**: Foundation for delegation, consensus, and hierarchical team patterns
- **MCP Integration**: Native Model Context Protocol support sets ElixirChain apart from competitors
- **Process-Per-Agent Model**: Leverages BEAM VM's unique concurrency strengths for true agent parallelism

#### Agent Specialization Strategy
Based on market research and hiring analysis:
- **Code Review Agent**: Enhanced with ElixirChain-specific patterns, BEAM VM optimization knowledge
- **Engineering Agent**: Deep OTP expertise, Gemini integration focus, performance targets (< 2s response, 1000+ concurrent agents)
- **Architecture Agent**: Distributed systems expertise for multi-node clusters and fault tolerance
- **Coordination Agent**: Multi-agent workflow patterns, consensus algorithms, team formation strategies
- **Performance Agent**: Memory optimization, latency reduction, scaling strategies specific to AI agent workloads

#### Agent Usage Best Practices
- **Always combine agent expertise**: Use multiple agents for complex problems (e.g., `elixir-ai-agent-engineer` + `performance-optimizer`)
- **Follow agent handoff patterns**: Structured workflow from architecture → implementation → review → optimization
- **Leverage agent-specific knowledge**: Each agent has ElixirChain-specific technical depth and performance targets
- **Document agent learnings**: Update CLAUDE.md with new patterns discovered during agent interactions

## Development Approach

### Phase 1 Priorities (Updated)
When implementation begins, focus on:

1. **Gemini Integration First**
   - Implement `ElixirChain.LLM.Gemini` as reference provider
   - Support 2M token context window fully
   - Design for multimodal capabilities (future)

2. **Simple Memory Management**
   - Start with ETS-based conversation memory
   - Leverage Gemini's large context to minimize complexity
   - Plan for pluggable backends (PostgreSQL, Redis, vector DBs)

3. **Basic Tool System**
   - Implement core tools: web_search, calculator, file_reader
   - Design for multimodal tool outputs
   - JSON Schema validation and timeout handling

4. **Agent Supervision**
   - GenServer-based agents with DynamicSupervisor
   - Automatic restart with conversation state recovery
   - Process isolation and resource boundaries

### Code Quality Standards
**Enhanced for AI Agent Development:**

- **Test LLM Integration**: Mock Gemini API for deterministic unit tests
- **Memory Safety**: Validate all inputs before pattern matching
- **Process Boundaries**: Clear separation between agent, memory, and tool processes
- **Context Management**: Efficient handling of large context windows
- **Fault Tolerance**: Design for graceful degradation when APIs fail

### Future Considerations
**Multimodal Agent Architecture:**
- Tool outputs can include images, documents, rich media
- Agent memory system must handle multimodal conversation history
- Chain execution engine should support multimodal data flow
- Consider Gemini's vision capabilities for agent tool integration

## GitHub Project Management Workflows

### Creating Milestones
Use year-first milestone format for proper sorting:

```bash
# Create milestones with proper formatting
gh api --method POST -H "Accept: application/vnd.github+json" /repos/OWNER/REPO/milestones \
  -f title="YYYY-Q[X] - Description" \
  -f due_on="YYYY-MM-DDT23:59:59Z" \
  -f description="Detailed milestone description"
```

### Creating Comprehensive Issues
Use heredoc format for multi-line issue bodies:

```bash
# Create comprehensive issues with heredoc bodies
gh issue create --repo OWNER/REPO --title "Title" --body "$(cat <<'EOF'
## Description
[Detailed description with context and goals]

## Acceptance Criteria
- [ ] Specific, testable criteria with checkboxes
- [ ] Technical implementation details
- [ ] Integration requirements

## Technical Details
```language
[Code examples and specifications]
```

## Related
- Links to design docs and dependencies
- Related issues and milestones
EOF
)" --label "label1" --label "label2" --milestone "Milestone Name"
```

### Project Organization Strategy
Effective issue breakdown by development phases:

- **Foundation Phase**: Core architecture, supervision trees, basic multi-agent communication
- **Feature Phase**: MCP support, advanced coordination patterns, comprehensive tool systems
- **Production Phase**: Distribution, performance optimization, security hardening
- **Ecosystem Phase**: Community tools, templates, integrations

### Issue Quality Standards
Successful issue format includes:
- Detailed acceptance criteria with checkboxes for tracking
- Technical implementation examples in properly formatted code blocks
- Clear relationships to other issues and design documents
- Progressive complexity aligned with milestone dependencies

## ElixirChain-Specific Architectural Insights

### Critical Fault Tolerance Requirements
- **Session Persistence is Essential**: Agents must survive crashes with full context recovery
- **Multi-Agent Communication Patterns**: Focus on delegation, consensus, and hierarchical teams
- **MCP Integration as Differentiator**: Native Model Context Protocol support sets ElixirChain apart
- **Leverage Gemini's 2M Token Context**: Enables simplified memory architecture compared to other frameworks

### Implementation Priorities (Session Learnings)
1. **Session Recovery First**: Build robust persistence before complex features
2. **Multi-Agent Foundation**: Communication infrastructure enables all advanced patterns
3. **MCP Native Integration**: Critical for ecosystem interoperability
4. **Progressive Feature Complexity**: Foundation → Core Features → Production → Ecosystem

## Troubleshooting

### rebar3 command not found

If you encounter an error like `(ErlangError) Erlang error: :enoent` when running `mix test`, it's likely that the path to the `rebar3` executable is not being resolved correctly. This can happen if the path contains a tilde (`~`), which is not always expanded in all shell contexts.

To fix this, you can set the `MIX_REBAR3` environment variable to the absolute path of the `rebar3` executable. You can find the path to `rebar3` by running `find ~/.mix -name rebar3`.

For example:

```bash
MIX_REBAR3="/home/rshade/.mix/elixir/1-18-otp-28/rebar3" mise exec -- mix test
```

To make this change permanent, you can add the following to your `Makefile`:

```makefile
REBAR3 = /home/rshade/.mix/elixir/1-18-otp-28/rebar3

test:
	@echo "==> Running tests..."
	@MIX_ENV=test MIX_REBAR3=$(REBAR3) $(MISE_EXEC) mix test
```

## Claude's Guidance
- **CRITICAL**: Always think systematically.
- **NEW**: Prioritize Gemini integration patterns in code examples
- **NEW**: Consider large context implications in memory management decisions
- **NEW**: Design for multimodal future while starting with text-only MVP
- **SESSION INSIGHT**: Session persistence and multi-agent communication are the core differentiators