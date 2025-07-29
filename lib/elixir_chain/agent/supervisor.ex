defmodule ElixirChain.Agent.Supervisor do
  @moduledoc """
  Supervisor module for managing agent processes with DynamicSupervisor integration.

  This module provides helper functions for starting, stopping, and managing
  agent processes within the ElixirChain supervision tree.
  """

  require Logger

  @doc """
  Starts a new agent under the AgentSupervisor.

  ## Options
    * `:id` - Unique identifier for the agent (required)
    * `:llm_provider` - Module implementing the LLM behavior
    * `:tools` - List of tool modules available to the agent
    * `:system_prompt` - System prompt for the agent
    * `:config` - Additional configuration map

  ## Examples

      iex> ElixirChain.Agent.Supervisor.start_agent(id: "agent-1")
      {:ok, #PID<0.123.0>}

      iex> ElixirChain.Agent.Supervisor.start_agent(
      ...>   id: "agent-2",
      ...>   llm_provider: ElixirChain.LLM.OpenAI
      ...> )
      {:ok, #PID<0.124.0>}
  """
  @spec start_agent(keyword()) :: DynamicSupervisor.on_start_child()
  def start_agent(opts) do
    agent_spec = {ElixirChain.Agent, opts}

    case DynamicSupervisor.start_child(ElixirChain.AgentSupervisor, agent_spec) do
      {:ok, pid} = success ->
        agent_id = Keyword.fetch!(opts, :id)
        Logger.info("Started agent #{agent_id} under supervision")
        success

      {:error, {:already_started, pid}} ->
        agent_id = Keyword.fetch!(opts, :id)
        Logger.warn("Agent #{agent_id} already started")
        {:ok, pid}

      {:error, reason} = error ->
        agent_id = Keyword.get(opts, :id, "unknown")
        Logger.error("Failed to start agent #{agent_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Stops an agent by terminating its process.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.stop_agent("agent-1")
      :ok

      iex> ElixirChain.Agent.Supervisor.stop_agent("nonexistent")
      {:error, :not_found}
  """
  @spec stop_agent(String.t()) :: :ok | {:error, :not_found}
  def stop_agent(agent_id) do
    case find_agent(agent_id) do
      {:ok, pid} ->
        case DynamicSupervisor.terminate_child(ElixirChain.AgentSupervisor, pid) do
          :ok ->
            Logger.info("Stopped agent #{agent_id}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to stop agent #{agent_id}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :not_found} = error ->
        Logger.warn("Attempted to stop non-existent agent #{agent_id}")
        error
    end
  end

  @doc """
  Restarts an agent by stopping and starting it again with the same configuration.

  The agent's original configuration is preserved and merged with any new options provided.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.restart_agent("agent-1")
      {:ok, #PID<0.125.0>}
  """
  @spec restart_agent(String.t(), keyword()) :: DynamicSupervisor.on_start_child() | {:error, :not_found}
  def restart_agent(agent_id, opts \\ []) do
    # First, retrieve the current configuration before stopping
    original_config =
      case ElixirChain.Agent.get_state(agent_id) do
        {:ok, state} ->
          # Extract configuration from state
          [
            id: state.id,
            llm_provider: state.llm_provider,
            tools: state.tools,
            system_prompt: state.system_prompt,
            config: state.config
          ]

        {:error, :not_found} ->
          []
      end

    case stop_agent(agent_id) do
      :ok ->
        # Merge original config with new opts (new opts take precedence)
        restart_opts = Keyword.merge(original_config, opts)
        start_agent(restart_opts)

      {:error, :not_found} = error ->
        error
    end
  end

  @doc """
  Lists all currently running agents.

  Returns a list of `{agent_id, pid}` tuples.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.list_agents()
      [{"agent-1", #PID<0.123.0>}, {"agent-2", #PID<0.124.0>}]
  """
  @spec list_agents() :: [{String.t(), pid()}]
  def list_agents do
    ElixirChain.AgentSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(ElixirChain.Agent.Registry, pid) do
        [agent_id] -> {agent_id, pid}
        [] -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Finds an agent process by its ID.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.find_agent("agent-1")
      {:ok, #PID<0.123.0>}

      iex> ElixirChain.Agent.Supervisor.find_agent("nonexistent")
      {:error, :not_found}
  """
  @spec find_agent(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def find_agent(agent_id) do
    case Registry.lookup(ElixirChain.Agent.Registry, agent_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns the count of currently running agents.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.agent_count()
      2
  """
  @spec agent_count() :: non_neg_integer()
  def agent_count do
    ElixirChain.AgentSupervisor
    |> DynamicSupervisor.count_children()
    |> Map.get(:active, 0)
  end

  @doc """
  Returns detailed information about all running agents.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.agent_info()
      [
        %{
          id: "agent-1",
          pid: #PID<0.123.0>,
          status: :running,
          memory_usage: 12345
        }
      ]
  """
  @spec agent_info() :: [map()]
  def agent_info do
    list_agents()
    |> Enum.map(fn {agent_id, pid} ->
      memory_usage =
        case Process.info(pid, :memory) do
          {:memory, memory} -> memory
          nil -> 0
        end

      status =
        case Process.alive?(pid) do
          true -> :running
          false -> :dead
        end

      %{
        id: agent_id,
        pid: pid,
        status: status,
        memory_usage: memory_usage
      }
    end)
  end

  @doc """
  Performs a health check on all running agents.

  Returns a map with `:healthy` and `:unhealthy` lists of agent information.

  ## Examples

      iex> ElixirChain.Agent.Supervisor.health_check_all()
      %{
        healthy: [%{id: "agent-1", pid: #PID<0.123.0>}],
        unhealthy: []
      }
  """
  @spec health_check_all() :: %{healthy: [map()], unhealthy: [map()]}
  def health_check_all do
    list_agents()
    |> Enum.reduce(%{healthy: [], unhealthy: []}, fn {agent_id, pid}, acc ->
      case ElixirChain.Agent.health_check(agent_id) do
        :ok ->
          Map.update!(acc, :healthy, &[%{id: agent_id, pid: pid} | &1])

        {:error, reason} ->
          Map.update!(acc, :unhealthy, &[%{id: agent_id, pid: pid, error: reason} | &1])
      end
    end)
  end

  @doc """
  Starts the agent supervisor helper module.

  This is a utility module that provides helper functions for agent management.
  The actual agent supervision is handled by ElixirChain.AgentSupervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    # This is a utility module, not a process supervisor
    # Return the existing AgentSupervisor process
    case Process.whereis(ElixirChain.AgentSupervisor) do
      nil -> {:error, :agent_supervisor_not_started}
      pid -> {:ok, pid}
    end
  end

  @doc """
  Returns the child specification for this supervisor.

  This allows the supervisor to be used in other supervision trees.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: :infinity
    }
  end
end
