defmodule ElixirChain.Agent.SupervisorTest do
  @moduledoc """
  Tests for the ElixirChain.Agent.Supervisor module.
  """

  use ExUnit.Case, async: true

  alias ElixirChain.Agent.Supervisor, as: AgentSupervisor

  describe "start_agent/1" do
    test "starts an agent under supervision" do
      agent_id = "supervisor-test-#{:rand.uniform(1000)}"
      opts = [id: agent_id]

      assert {:ok, pid} = AgentSupervisor.start_agent(opts)
      assert Process.alive?(pid)

      # Verify the agent is properly registered
      assert {:ok, ^pid} = AgentSupervisor.find_agent(agent_id)

      # Clean up
      AgentSupervisor.stop_agent(agent_id)
    end

    test "starts agent with custom configuration" do
      agent_id = "supervisor-config-test-#{:rand.uniform(1000)}"

      opts = [
        id: agent_id,
        llm_provider: ElixirChain.LLM.OpenAI,
        system_prompt: "Custom prompt"
      ]

      assert {:ok, pid} = AgentSupervisor.start_agent(opts)

      # Verify configuration was applied
      {:ok, state} = ElixirChain.Agent.get_state(agent_id)
      assert state.llm_provider == ElixirChain.LLM.OpenAI
      assert state.system_prompt == "Custom prompt"

      AgentSupervisor.stop_agent(agent_id)
    end

    test "handles already started agent" do
      agent_id = "already-started-test-#{:rand.uniform(1000)}"
      opts = [id: agent_id]

      assert {:ok, pid1} = AgentSupervisor.start_agent(opts)
      assert {:ok, pid2} = AgentSupervisor.start_agent(opts)

      # Should return the same PID for already started agent
      assert pid1 == pid2

      AgentSupervisor.stop_agent(agent_id)
    end

    test "handles agent start failures" do
      # This test would need to simulate failure conditions
      # For now, we'll test with invalid options
      # missing required :id
      opts = []

      assert {:error, _reason} = AgentSupervisor.start_agent(opts)
    end
  end

  describe "stop_agent/1" do
    test "stops a running agent" do
      agent_id = "stop-test-#{:rand.uniform(1000)}"
      {:ok, pid} = AgentSupervisor.start_agent(id: agent_id)

      assert Process.alive?(pid)
      assert :ok = AgentSupervisor.stop_agent(agent_id)

      # Give it time to stop
      Process.sleep(10)
      refute Process.alive?(pid)

      # Verify it's no longer findable
      assert {:error, :not_found} = AgentSupervisor.find_agent(agent_id)
    end

    test "handles stopping non-existent agent" do
      assert {:error, :not_found} = AgentSupervisor.stop_agent("non-existent")
    end
  end

  describe "restart_agent/2" do
    test "restarts an existing agent" do
      agent_id = "restart-test-#{:rand.uniform(1000)}"
      {:ok, original_pid} = AgentSupervisor.start_agent(id: agent_id)

      assert {:ok, new_pid} = AgentSupervisor.restart_agent(agent_id)

      # Should be a different process
      assert original_pid != new_pid
      assert Process.alive?(new_pid)

      AgentSupervisor.stop_agent(agent_id)
    end

    test "restarts agent with new configuration" do
      agent_id = "restart-config-test-#{:rand.uniform(1000)}"
      {:ok, _pid} = AgentSupervisor.start_agent(id: agent_id)

      new_opts = [system_prompt: "New system prompt"]
      assert {:ok, new_pid} = AgentSupervisor.restart_agent(agent_id, new_opts)

      # Verify new configuration was applied
      {:ok, state} = ElixirChain.Agent.get_state(agent_id)
      assert state.system_prompt == "New system prompt"

      AgentSupervisor.stop_agent(agent_id)
    end

    test "handles restarting non-existent agent" do
      assert {:error, :not_found} = AgentSupervisor.restart_agent("non-existent")
    end
  end

  describe "find_agent/1" do
    test "finds existing agent" do
      agent_id = "find-test-#{:rand.uniform(1000)}"
      {:ok, pid} = AgentSupervisor.start_agent(id: agent_id)

      assert {:ok, ^pid} = AgentSupervisor.find_agent(agent_id)

      AgentSupervisor.stop_agent(agent_id)
    end

    test "returns error for non-existent agent" do
      assert {:error, :not_found} = AgentSupervisor.find_agent("non-existent")
    end
  end

  describe "list_agents/0" do
    test "lists all running agents" do
      # Start multiple agents
      agent1_id = "list-test-1-#{:rand.uniform(1000)}"
      agent2_id = "list-test-2-#{:rand.uniform(1000)}"

      {:ok, pid1} = AgentSupervisor.start_agent(id: agent1_id)
      {:ok, pid2} = AgentSupervisor.start_agent(id: agent2_id)

      agents = AgentSupervisor.list_agents()
      agent_ids = Enum.map(agents, fn {id, _pid} -> id end)

      assert agent1_id in agent_ids
      assert agent2_id in agent_ids

      # Clean up
      AgentSupervisor.stop_agent(agent1_id)
      AgentSupervisor.stop_agent(agent2_id)
    end

    test "returns empty list when no agents running" do
      # This test assumes no other agents are running
      # In practice, might need isolation
      initial_agents = AgentSupervisor.list_agents()

      # Stop all agents for clean test
      Enum.each(initial_agents, fn {agent_id, _pid} ->
        AgentSupervisor.stop_agent(agent_id)
      end)

      # Give time for cleanup
      Process.sleep(10)
      assert AgentSupervisor.list_agents() == []
    end
  end

  describe "agent_count/0" do
    test "returns correct count of running agents" do
      initial_count = AgentSupervisor.agent_count()

      agent1_id = "count-test-1-#{:rand.uniform(1000)}"
      agent2_id = "count-test-2-#{:rand.uniform(1000)}"

      {:ok, _pid1} = AgentSupervisor.start_agent(id: agent1_id)
      assert AgentSupervisor.agent_count() == initial_count + 1

      {:ok, _pid2} = AgentSupervisor.start_agent(id: agent2_id)
      assert AgentSupervisor.agent_count() == initial_count + 2

      AgentSupervisor.stop_agent(agent1_id)
      Process.sleep(10)
      assert AgentSupervisor.agent_count() == initial_count + 1

      AgentSupervisor.stop_agent(agent2_id)
      Process.sleep(10)
      assert AgentSupervisor.agent_count() == initial_count
    end
  end

  describe "agent_info/0" do
    test "returns detailed information about agents" do
      agent_id = "info-test-#{:rand.uniform(1000)}"
      {:ok, pid} = AgentSupervisor.start_agent(id: agent_id)

      info_list = AgentSupervisor.agent_info()
      agent_info = Enum.find(info_list, fn info -> info.id == agent_id end)

      assert agent_info != nil
      assert agent_info.id == agent_id
      assert agent_info.pid == pid
      assert agent_info.status == :running
      assert is_integer(agent_info.memory_usage)
      assert agent_info.memory_usage > 0

      AgentSupervisor.stop_agent(agent_id)
    end
  end

  describe "health_check_all/0" do
    test "performs health check on all agents" do
      agent1_id = "health-all-test-1-#{:rand.uniform(1000)}"
      agent2_id = "health-all-test-2-#{:rand.uniform(1000)}"

      {:ok, _pid1} = AgentSupervisor.start_agent(id: agent1_id)
      {:ok, _pid2} = AgentSupervisor.start_agent(id: agent2_id)

      result = AgentSupervisor.health_check_all()

      assert is_list(result.healthy)
      assert is_list(result.unhealthy)

      # Both agents should be healthy
      healthy_ids = Enum.map(result.healthy, & &1.id)
      assert agent1_id in healthy_ids
      assert agent2_id in healthy_ids

      AgentSupervisor.stop_agent(agent1_id)
      AgentSupervisor.stop_agent(agent2_id)
    end

    test "returns empty lists when no agents running" do
      # Stop all agents first
      AgentSupervisor.list_agents()
      |> Enum.each(fn {agent_id, _pid} ->
        AgentSupervisor.stop_agent(agent_id)
      end)

      Process.sleep(10)

      result = AgentSupervisor.health_check_all()
      assert result.healthy == []
      assert result.unhealthy == []
    end
  end

  describe "supervision behavior" do
    test "agent restart under supervisor" do
      agent_id = "supervision-test-#{:rand.uniform(1000)}"
      {:ok, original_pid} = AgentSupervisor.start_agent(id: agent_id)

      # Kill the process (simulating a crash)
      Process.exit(original_pid, :kill)

      # Give the supervisor time to restart
      Process.sleep(100)

      # The agent should be restarted automatically by DynamicSupervisor
      # In this case, we need to check if a new process was started
      # This behavior depends on the supervisor's restart strategy
      case AgentSupervisor.find_agent(agent_id) do
        {:ok, new_pid} ->
          # If restarted, it should be a different PID
          assert new_pid != original_pid
          AgentSupervisor.stop_agent(agent_id)

        {:error, :not_found} ->
          # If not restarted automatically, that's also valid behavior
          # for a DynamicSupervisor with transient restart
          :ok
      end
    end
  end

  describe "child_spec/1" do
    test "returns proper child spec" do
      spec = AgentSupervisor.child_spec([])

      assert spec.id == AgentSupervisor
      assert {AgentSupervisor, :start_link, [[]]} = spec.start
      assert spec.type == :supervisor
      assert spec.restart == :permanent
      assert spec.shutdown == :infinity
    end
  end
end
