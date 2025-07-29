defmodule ElixirChain.Agent do
  @moduledoc """
  Core Agent GenServer that manages individual AI agent processes.

  Each agent runs as an independent GenServer process with:
  - Process isolation for fault tolerance
  - Automatic restart on crashes
  - Hot code swapping support
  - Built-in health monitoring
  """

  use GenServer

  require Logger

  @type agent_id :: String.t()
  @type state :: %{
          id: agent_id(),
          llm_provider: module(),
          tools: [module()],
          memory_pid: pid() | nil,
          system_prompt: String.t(),
          config: map(),
          conversation_state: map()
        }

  # Client API

  @doc """
  Starts a new agent process linked to the current process.

  ## Options
    * `:id` - Unique identifier for the agent (required)
    * `:llm_provider` - Module implementing the LLM behavior (default: ElixirChain.LLM.Gemini)
    * `:tools` - List of tool modules available to the agent (default: [])
    * `:system_prompt` - System prompt for the agent (default: "You are a helpful AI assistant.")
    * `:config` - Additional configuration map (default: %{})

  ## Examples

      iex> {:ok, agent} = ElixirChain.Agent.start_link(id: "agent-1")
      {:ok, #PID<0.123.0>}

      iex> {:ok, agent} = ElixirChain.Agent.start_link(
      ...>   id: "agent-2",
      ...>   llm_provider: ElixirChain.LLM.OpenAI,
      ...>   tools: [ElixirChain.Tools.WebSearch, ElixirChain.Tools.Calculator]
      ...> )
      {:ok, #PID<0.124.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    name = via_tuple(id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Sends a chat message to the agent and receives a response.

  ## Examples

      iex> ElixirChain.Agent.chat("agent-1", "Hello, how are you?")
      {:ok, "I'm doing well, thank you! How can I help you today?"}
  """
  @spec chat(agent_id(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def chat(agent_id, message) do
    GenServer.call(via_tuple(agent_id), {:chat, message})
  catch
    :exit, {:noproc, _} -> {:error, :noproc}
  end

  @doc """
  Gets the current state of the agent.
  """
  @spec get_state(agent_id()) :: {:ok, state()} | {:error, :not_found}
  def get_state(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_state)
  catch
    :exit, {:noproc, _} -> {:error, :not_found}
  end

  @doc """
  Performs a health check on the agent.
  """
  @spec health_check(agent_id()) :: :ok | {:error, term()}
  def health_check(agent_id) do
    GenServer.call(via_tuple(agent_id), :health_check)
  catch
    :exit, {:noproc, _} -> {:error, :not_found}
  end

  @doc """
  Stops the agent process gracefully.
  """
  @spec stop(agent_id()) :: :ok
  def stop(agent_id) do
    GenServer.stop(via_tuple(agent_id))
  catch
    :exit, {:noproc, _} -> :ok
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    id = Keyword.fetch!(opts, :id)
    llm_provider = Keyword.get(opts, :llm_provider, ElixirChain.LLM.Gemini)
    tools = Keyword.get(opts, :tools, [])
    system_prompt = Keyword.get(opts, :system_prompt, "You are a helpful AI assistant.")
    config = Keyword.get(opts, :config, %{})

    state = %{
      id: id,
      llm_provider: llm_provider,
      tools: tools,
      memory_pid: nil,
      system_prompt: system_prompt,
      config: config,
      conversation_state: %{
        messages: [],
        context: %{}
      }
    }

    Logger.info("Started agent #{id} with provider #{inspect(llm_provider)}")

    # Emit telemetry event
    :telemetry.execute(
      [:elixir_chain, :agent, :created],
      %{count: 1},
      %{agent_id: id, llm_provider: llm_provider}
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:chat, message}, _from, state) do
    start_time = System.monotonic_time()

    case process_chat(message, state) do
      {:ok, response, new_state} ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:elixir_chain, :agent, :response],
          %{duration: duration},
          %{agent_id: state.id}
        )

        {:reply, {:ok, response}, new_state}

      {:error, reason} = error ->
        :telemetry.execute(
          [:elixir_chain, :agent, :error],
          %{count: 1},
          %{agent_id: state.id, error: reason}
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.warn("Agent #{state.id} received EXIT signal: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Agent #{state.id} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Agent #{state.id} terminating: #{inspect(reason)}")
    :ok
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    Logger.info("Agent #{state.id} code change")
    {:ok, state}
  end

  # Private Functions

  defp via_tuple(agent_id) do
    {:via, Registry, {ElixirChain.Agent.Registry, agent_id}}
  end

  defp process_chat(message, state) do
    # This is a placeholder implementation
    # In a real implementation, this would:
    # 1. Add the message to conversation history
    # 2. Call the LLM provider
    # 3. Process any tool calls
    # 4. Update the conversation state

    new_conversation_state = %{
      state.conversation_state
      | messages: state.conversation_state.messages ++ [%{role: "user", content: message}]
    }

    response = "This is a placeholder response. LLM integration pending."

    new_state = %{state | conversation_state: new_conversation_state}
    {:ok, response, new_state}
  end
end
