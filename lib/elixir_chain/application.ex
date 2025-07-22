defmodule ElixirChain.Application do
  @moduledoc """
  The ElixirChain OTP Application.

  This module starts the supervision tree for the ElixirChain framework,
  including agent supervision, memory management, tool registry, and
  HTTP client pools.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ElixirChain Application...")

    children = [
      # Telemetry supervisor
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()},
      
      # HTTP client pool
      {Finch, name: ElixirChain.Finch},
      
      # Tool Registry
      {Registry, keys: :unique, name: ElixirChain.Tool.Registry},
      
      # Agent Registry
      {Registry, keys: :unique, name: ElixirChain.Agent.Registry},
      
      # Memory Registry
      {Registry, keys: :unique, name: ElixirChain.Memory.Registry},
      
      # Dynamic Supervisor for Agents
      {DynamicSupervisor, name: ElixirChain.AgentSupervisor, strategy: :one_for_one},
      
      # Dynamic Supervisor for Memory Processes
      {DynamicSupervisor, name: ElixirChain.MemorySupervisor, strategy: :one_for_one},
      
      # Cache for LLM responses
      {Cachex, name: :llm_cache}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirChain.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("ElixirChain Application started successfully")
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("Failed to start ElixirChain Application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping ElixirChain Application...")
    :ok
  end

  defp metrics do
    [
      # Agent metrics
      Telemetry.Metrics.counter("elixir_chain.agent.created.count"),
      Telemetry.Metrics.counter("elixir_chain.agent.error.count"),
      Telemetry.Metrics.summary("elixir_chain.agent.response.duration"),
      
      # LLM metrics
      Telemetry.Metrics.counter("elixir_chain.llm.request.count"),
      Telemetry.Metrics.counter("elixir_chain.llm.error.count"),
      Telemetry.Metrics.summary("elixir_chain.llm.response.duration"),
      Telemetry.Metrics.summary("elixir_chain.llm.tokens.used"),
      
      # Tool metrics
      Telemetry.Metrics.counter("elixir_chain.tool.execution.count"),
      Telemetry.Metrics.counter("elixir_chain.tool.error.count"),
      Telemetry.Metrics.summary("elixir_chain.tool.execution.duration"),
      
      # Memory metrics
      Telemetry.Metrics.counter("elixir_chain.memory.read.count"),
      Telemetry.Metrics.counter("elixir_chain.memory.write.count"),
      Telemetry.Metrics.summary("elixir_chain.memory.operation.duration"),
      
      # Cache metrics
      Telemetry.Metrics.counter("elixir_chain.cache.hit.count"),
      Telemetry.Metrics.counter("elixir_chain.cache.miss.count")
    ]
  end
end