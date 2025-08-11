defmodule ElixirChain.Agent.RegistryTest do
  @moduledoc """
  Tests for agent registry functionality and discovery.
  """

  use ExUnit.Case, async: true

  alias ElixirChain.Agent
  alias ElixirChain.Agent.Supervisor, as: AgentSupervisor

  describe "agent registry integration" do
    test "agent registers itself on startup" do
      agent_id = "registry-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Check that the agent is registered
      assert [{^pid, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      GenServer.stop(pid)
    end

    test "agent unregisters itself on shutdown" do
      agent_id = "unregister-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Verify registration
      assert [{^pid, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      # Stop the agent
      GenServer.stop(pid)

      # Give it time to clean up
      Process.sleep(10)

      # Should no longer be registered
      assert [] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)
    end

    test "multiple agents can register with different IDs" do
      agent1_id = "multi-reg-test-1-#{:rand.uniform(1000)}"
      agent2_id = "multi-reg-test-2-#{:rand.uniform(1000)}"

      {:ok, pid1} = Agent.start_link(id: agent1_id)
      {:ok, pid2} = Agent.start_link(id: agent2_id)

      # Both should be registered
      assert [{^pid1, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent1_id)
      assert [{^pid2, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent2_id)

      GenServer.stop(pid1)
      GenServer.stop(pid2)
    end

    test "prevents duplicate registrations" do
      agent_id = "duplicate-reg-test-#{:rand.uniform(1000)}"
      {:ok, pid1} = Agent.start_link(id: agent_id)

      # Attempting to start another agent with the same ID should fail
      assert {:error, {:already_started, _}} = Agent.start_link(id: agent_id)

      # Only the original should be registered
      assert [{^pid1, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      GenServer.stop(pid1)
    end
  end

  describe "discovery through registry" do
    test "can find agent by ID through registry" do
      agent_id = "discovery-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Find through supervisor helper
      assert {:ok, ^pid} = AgentSupervisor.find_agent(agent_id)

      # Direct registry lookup should also work
      assert [{^pid, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      GenServer.stop(pid)
    end

    test "returns not found for non-existent agent" do
      assert {:error, :not_found} = AgentSupervisor.find_agent("non-existent-#{:rand.uniform(1000)}")
      assert [] = Registry.lookup(ElixirChain.Agent.Registry, "non-existent-#{:rand.uniform(1000)}")
    end

    test "can list all registered agents" do
      agent1_id = "list-discovery-1-#{:rand.uniform(1000)}"
      agent2_id = "list-discovery-2-#{:rand.uniform(1000)}"

      {:ok, pid1} = Agent.start_link(id: agent1_id)
      {:ok, pid2} = Agent.start_link(id: agent2_id)

      agents = AgentSupervisor.list_agents()
      agent_ids = Enum.map(agents, fn {id, _pid} -> id end)

      assert agent1_id in agent_ids
      assert agent2_id in agent_ids

      # Verify PIDs match
      assert {agent1_id, pid1} in agents
      assert {agent2_id, pid2} in agents

      GenServer.stop(pid1)
      GenServer.stop(pid2)
    end
  end

  describe "registry behavior under failures" do
    test "registry cleans up when agent process dies" do
      agent_id = "crash-cleanup-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Verify registration
      assert [{^pid, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      # Kill the process
      Process.exit(pid, :kill)

      # Give registry time to clean up
      Process.sleep(50)

      # Should be cleaned up from registry
      assert [] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)
    end

    test "can start new agent with same ID after previous one dies" do
      agent_id = "reuse-id-test-#{:rand.uniform(1000)}"
      {:ok, pid1} = Agent.start_link(id: agent_id)

      # Kill the first process
      Process.exit(pid1, :kill)
      Process.sleep(50)

      # Should be able to start a new agent with the same ID
      {:ok, pid2} = Agent.start_link(id: agent_id)
      assert pid1 != pid2

      # New agent should be registered
      assert [{^pid2, _}] = Registry.lookup(ElixirChain.Agent.Registry, agent_id)

      GenServer.stop(pid2)
    end
  end

  describe "registry metadata" do
    test "registry stores process metadata" do
      agent_id = "metadata-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Registry lookup should return the process
      case Registry.lookup(ElixirChain.Agent.Registry, agent_id) do
        [{^pid, _metadata}] ->
          # Registry is working correctly
          :ok

        [] ->
          flunk("Agent not found in registry")
      end

      GenServer.stop(pid)
    end

    test "can enumerate all registry entries" do
      agent1_id = "enum-test-1-#{:rand.uniform(1000)}"
      agent2_id = "enum-test-2-#{:rand.uniform(1000)}"

      {:ok, pid1} = Agent.start_link(id: agent1_id)
      {:ok, pid2} = Agent.start_link(id: agent2_id)

      # Get all registry entries
      registry_keys =
        Registry.select(ElixirChain.Agent.Registry, [
          {{:"$1", :_, :_}, [], [:"$1"]}
        ])

      assert agent1_id in registry_keys
      assert agent2_id in registry_keys

      GenServer.stop(pid1)
      GenServer.stop(pid2)
    end
  end

  describe "via tuple integration" do
    test "via tuple resolves to correct process" do
      agent_id = "via-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Via tuple should resolve to the correct PID
      via_tuple = {:via, Registry, {ElixirChain.Agent.Registry, agent_id}}
      assert GenServer.whereis(via_tuple) == pid

      GenServer.stop(pid)
    end

    test "can send messages using via tuple" do
      agent_id = "via-message-test-#{:rand.uniform(1000)}"
      {:ok, _pid} = Agent.start_link(id: agent_id)

      # Should be able to communicate through via tuple
      assert {:ok, _response} = Agent.chat(agent_id, "test message")
      assert :ok = Agent.health_check(agent_id)

      Agent.stop(agent_id)
    end

    test "via tuple returns :undefined for non-existent agent" do
      via_tuple = {:via, Registry, {ElixirChain.Agent.Registry, "non-existent"}}
      assert GenServer.whereis(via_tuple) == nil
    end
  end
end
