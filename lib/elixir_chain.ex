defmodule ElixirChain do
  @moduledoc """
  ElixirChain is a LangChain-equivalent framework built in Elixir that leverages 
  the BEAM VM's concurrency, fault tolerance, and distributed computing capabilities 
  to create robust AI agent systems.

  ## Overview

  ElixirChain treats each agent as a supervised process, enabling true parallelism 
  and automatic fault recovery. This provides significant advantages over traditional 
  Python-based frameworks:

  - **Process Isolation**: Each agent runs independently
  - **Fault Tolerance**: Automatic recovery from crashes
  - **True Parallelism**: Leverage all CPU cores
  - **Hot Code Swapping**: Update agents without downtime
  - **Distributed Computing**: Scale across multiple nodes

  ## Quick Start

      # Start an agent
      {:ok, agent} = ElixirChain.start_agent(%{
        name: "assistant",
        system_prompt: "You are a helpful assistant",
        llm_provider: :openai
      })

      # Chat with the agent
      {:ok, response} = ElixirChain.chat(agent, "Hello!")

      # Stream responses
      stream = ElixirChain.chat_stream(agent, "Tell me a story")
      for chunk <- stream do
        IO.write(chunk)
      end

  ## Architecture

  The framework is organized into several key components:

  - **Agent System**: Core agent processes and supervision
  - **LLM Providers**: Abstractions for OpenAI, Anthropic, and local models
  - **Memory System**: Conversation history and vector storage
  - **Tool System**: Extensible tool framework for agent capabilities
  - **Chain Engine**: Composable execution patterns
  """

  alias ElixirChain.{Agent, Chain}

  @doc """
  Starts a new agent with the given configuration.

  ## Options

    * `:name` - A unique name for the agent (optional)
    * `:system_prompt` - The system prompt for the agent
    * `:llm_provider` - The LLM provider module (default: `:openai`)
    * `:tools` - List of tool modules to enable
    * `:memory_type` - Type of memory to use (default: `:conversation`)
    * `:temperature` - LLM temperature setting (0.0-2.0)
    * `:max_tokens` - Maximum tokens in response

  ## Examples

      {:ok, agent} = ElixirChain.start_agent(%{
        name: "researcher",
        system_prompt: "You are a research assistant",
        tools: [:web_search, :calculator],
        temperature: 0.7
      })

  """
  def start_agent(config) do
    DynamicSupervisor.start_child(
      ElixirChain.AgentSupervisor,
      {Agent, config}
    )
  end

  @doc """
  Sends a message to an agent and receives a response.

  ## Examples

      {:ok, response} = ElixirChain.chat(agent, "What's the weather?")

  """
  def chat(agent, message, opts \\ []) do
    Agent.chat(agent, message, opts)
  end

  @doc """
  Sends a message to an agent and receives a streaming response.

  Returns a stream that yields response chunks as they arrive.

  ## Examples

      stream = ElixirChain.chat_stream(agent, "Write a long story")
      for chunk <- stream do
        IO.write(chunk)
      end

  """
  def chat_stream(agent, message, opts \\ []) do
    Agent.chat_stream(agent, message, opts)
  end

  @doc """
  Adds a tool to an agent's available tools.

  ## Examples

      :ok = ElixirChain.add_tool(agent, MyCustomTool)

  """
  def add_tool(agent, tool_module) do
    Agent.add_tool(agent, tool_module)
  end

  @doc """
  Removes a tool from an agent's available tools.

  ## Examples

      :ok = ElixirChain.remove_tool(agent, :calculator)

  """
  def remove_tool(agent, tool_name) do
    Agent.remove_tool(agent, tool_name)
  end

  @doc """
  Clears an agent's conversation memory.

  ## Examples

      :ok = ElixirChain.clear_memory(agent)

  """
  def clear_memory(agent) do
    Agent.clear_memory(agent)
  end

  @doc """
  Retrieves an agent's conversation history.

  ## Examples

      history = ElixirChain.get_conversation_history(agent)

  """
  def get_conversation_history(agent) do
    Agent.get_conversation_history(agent)
  end

  @doc """
  Creates a new execution chain.

  ## Examples

      chain = ElixirChain.create_chain()
      |> ElixirChain.add_llm_step(:openai, "Summarize: {{text}}")
      |> ElixirChain.add_tool_step(:web_search, %{query: "{{query}}"})

  """
  def create_chain(opts \\ []) do
    Chain.new(opts)
  end

  @doc """
  Adds an LLM step to a chain.
  """
  def add_llm_step(chain, provider, prompt, opts \\ []) do
    Chain.add_step(chain, {:llm, provider, prompt, opts})
  end

  @doc """
  Adds a tool step to a chain.
  """
  def add_tool_step(chain, tool, args) do
    Chain.add_step(chain, {:tool, tool, args})
  end

  @doc """
  Executes a chain with the given input.

  ## Examples

      {:ok, result} = ElixirChain.run_chain(chain, %{text: "Hello world"})

  """
  def run_chain(chain, input) do
    Chain.run(chain, input)
  end

  @doc """
  Lists all active agents.

  ## Examples

      agents = ElixirChain.list_agents()

  """
  def list_agents do
    Registry.select(ElixirChain.Agent.Registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {name, pid, _value} -> {name, pid} end)
  end

  @doc """
  Stops an agent.

  ## Examples

      :ok = ElixirChain.stop_agent(agent)

  """
  def stop_agent(agent) do
    DynamicSupervisor.terminate_child(ElixirChain.AgentSupervisor, agent)
  end

  @doc """
  Gets agent information and statistics.

  ## Examples

      info = ElixirChain.agent_info(agent)

  """
  def agent_info(agent) do
    Agent.get_info(agent)
  end
end