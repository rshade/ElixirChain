# ElixirChain

A LangChain-equivalent framework built in Elixir that leverages the BEAM VM's concurrency, fault tolerance, and distributed computing capabilities to create robust AI agent systems.

## Features

- **Process-Based Agents**: Each agent runs as a supervised GenServer process
- **Fault Tolerance**: Automatic recovery from crashes with supervision trees
- **True Parallelism**: Leverage all CPU cores with concurrent agent execution
- **Pluggable LLM Providers**: Support for OpenAI, Anthropic, and local models
- **Memory Management**: Multiple memory types with pluggable storage backends
- **Tool System**: Extensible framework for agent capabilities
- **Chain Execution**: Composable patterns for complex workflows
- **Distributed Support**: Scale across multiple nodes seamlessly

## Installation

Add `elixir_chain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixir_chain, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Start an agent
{:ok, agent} = ElixirChain.start_agent(%{
  name: "assistant",
  system_prompt: "You are a helpful assistant",
  tools: [:web_search, :calculator],
  llm_provider: :openai
})

# Chat with the agent
{:ok, response} = ElixirChain.chat(agent, "What's the weather in San Francisco?")

# Stream responses
stream = ElixirChain.chat_stream(agent, "Write a story about Elixir")
for chunk <- stream do
  IO.write(chunk)
end
```

## Development Setup

### Prerequisites

- Erlang/OTP 26+
- Elixir 1.15+
- PostgreSQL 13+ (for vector storage)
- Redis 6+ (for caching)

### Quick Setup

```bash
# Install development tools
make ensure

# Complete project setup
make setup

# Run tests
make test

# Start interactive console
make console
```

## Documentation

Full documentation is available at [https://hexdocs.pm/elixir_chain](https://hexdocs.pm/elixir_chain).

For the technical design document, see [elixir_chain_design_doc.md](elixir_chain_design_doc.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.