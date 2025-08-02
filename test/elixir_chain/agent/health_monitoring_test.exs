defmodule ElixirChain.Agent.HealthMonitoringTest do
  @moduledoc """
  Tests for agent health check and monitoring functionality.
  """

  use ExUnit.Case, async: true

  alias ElixirChain.Agent
  alias ElixirChain.Agent.Supervisor, as: AgentSupervisor

  describe "individual agent health checks" do
    test "healthy agent responds to health check" do
      agent_id = "health-individual-#{:rand.uniform(1000)}"
      {:ok, _pid} = Agent.start_link(id: agent_id)

      assert :ok = Agent.health_check(agent_id)

      Agent.stop(agent_id)
    end

    test "health check fails for non-existent agent" do
      assert {:error, :not_found} = Agent.health_check("non-existent-#{:rand.uniform(1000)}")
    end

    test "health check works after agent processes messages" do
      agent_id = "health-after-work-#{:rand.uniform(1000)}"
      {:ok, _pid} = Agent.start_link(id: agent_id)

      # Process some messages
      {:ok, _} = Agent.chat(agent_id, "test message 1")
      {:ok, _} = Agent.chat(agent_id, "test message 2")

      # Health check should still work
      assert :ok = Agent.health_check(agent_id)

      Agent.stop(agent_id)
    end
  end

  describe "bulk health monitoring" do
    test "health check all with multiple healthy agents" do
      agent1_id = "bulk-health-1-#{:rand.uniform(1000)}"
      agent2_id = "bulk-health-2-#{:rand.uniform(1000)}"
      agent3_id = "bulk-health-3-#{:rand.uniform(1000)}"

      {:ok, _pid1} = Agent.start_link(id: agent1_id)
      {:ok, _pid2} = Agent.start_link(id: agent2_id)
      {:ok, _pid3} = Agent.start_link(id: agent3_id)

      result = AgentSupervisor.health_check_all()

      # All agents should be healthy
      healthy_ids = Enum.map(result.healthy, & &1.id)
      assert agent1_id in healthy_ids
      assert agent2_id in healthy_ids
      assert agent3_id in healthy_ids

      # No unhealthy agents
      assert result.unhealthy == []

      # Clean up
      Agent.stop(agent1_id)
      Agent.stop(agent2_id)
      Agent.stop(agent3_id)
    end

    test "health check all returns proper structure" do
      agent_id = "health-structure-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      result = AgentSupervisor.health_check_all()

      assert Map.has_key?(result, :healthy)
      assert Map.has_key?(result, :unhealthy)
      assert is_list(result.healthy)
      assert is_list(result.unhealthy)

      # Find our agent in the healthy list
      agent_health = Enum.find(result.healthy, &(&1.id == agent_id))
      assert agent_health != nil
      assert agent_health.id == agent_id
      assert agent_health.pid == pid

      Agent.stop(agent_id)
    end

    test "health check all with no agents" do
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

  describe "agent information monitoring" do
    test "agent info returns detailed information" do
      agent_id = "info-monitoring-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      info_list = AgentSupervisor.agent_info()
      agent_info = Enum.find(info_list, &(&1.id == agent_id))

      assert agent_info != nil
      assert agent_info.id == agent_id
      assert agent_info.pid == pid
      assert agent_info.status == :running
      assert is_integer(agent_info.memory_usage)
      assert agent_info.memory_usage > 0

      Agent.stop(agent_id)
    end

    test "agent info shows memory usage changes" do
      agent_id = "memory-monitoring-#{:rand.uniform(1000)}"
      {:ok, _pid} = Agent.start_link(id: agent_id)

      # Get initial memory usage
      initial_info = AgentSupervisor.agent_info()
      initial_agent = Enum.find(initial_info, &(&1.id == agent_id))
      initial_memory = initial_agent.memory_usage

      # Process several messages (might increase memory usage)
      Enum.each(1..10, fn i ->
        Agent.chat(agent_id, "Message number #{i}")
      end)

      # Get updated memory usage
      updated_info = AgentSupervisor.agent_info()
      updated_agent = Enum.find(updated_info, &(&1.id == agent_id))
      updated_memory = updated_agent.memory_usage

      # Memory usage should be tracked (might be same or different)
      assert is_integer(updated_memory)
      assert updated_memory > 0

      Agent.stop(agent_id)
    end

    test "agent count is accurate" do
      initial_count = AgentSupervisor.agent_count()

      agent1_id = "count-monitoring-1-#{:rand.uniform(1000)}"
      agent2_id = "count-monitoring-2-#{:rand.uniform(1000)}"

      {:ok, _pid1} = Agent.start_link(id: agent1_id)
      assert AgentSupervisor.agent_count() == initial_count + 1

      {:ok, _pid2} = Agent.start_link(id: agent2_id)
      assert AgentSupervisor.agent_count() == initial_count + 2

      Agent.stop(agent1_id)
      Process.sleep(10)
      assert AgentSupervisor.agent_count() == initial_count + 1

      Agent.stop(agent2_id)
      Process.sleep(10)
      assert AgentSupervisor.agent_count() == initial_count
    end
  end

  describe "process monitoring" do
    test "agent process is alive after creation" do
      agent_id = "process-alive-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      assert Process.alive?(pid)

      Agent.stop(agent_id)
    end

    test "can monitor agent process lifecycle" do
      agent_id = "lifecycle-monitoring-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Monitor the process
      ref = Process.monitor(pid)

      assert Process.alive?(pid)

      # Stop the agent
      Agent.stop(agent_id)

      # Should receive DOWN message
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end

    test "agent process info is accessible" do
      agent_id = "process-info-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Should be able to get process info
      info = Process.info(pid)
      assert info != nil
      assert Keyword.has_key?(info, :status)
      assert Keyword.has_key?(info, :memory)
      assert Keyword.has_key?(info, :message_queue_len)

      Agent.stop(agent_id)
    end
  end

  describe "telemetry monitoring" do
    test "agent creation emits telemetry events" do
      agent_id = "telemetry-creation-#{:rand.uniform(1000)}"
      test_pid = self()
      ref = make_ref()

      # Attach telemetry handler
      :telemetry.attach(
        "test-agent-created-#{inspect(ref)}",
        [:elixir_chain, :agent, :created],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_created, ref, measurements, metadata})
        end,
        nil
      )

      {:ok, _pid} = Agent.start_link(id: agent_id)

      # Should receive telemetry event
      assert_receive {:telemetry_created, ^ref, %{count: 1}, metadata}, 1000
      assert metadata.agent_id == agent_id

      :telemetry.detach("test-agent-created-#{ref}")
      Agent.stop(agent_id)
    end

    test "agent chat emits response telemetry events" do
      agent_id = "telemetry-response-#{:rand.uniform(1000)}"
      test_pid = self()
      ref = make_ref()

      # Attach telemetry handler
      :telemetry.attach(
        "test-agent-response-#{inspect(ref)}",
        [:elixir_chain, :agent, :response],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_response, ref, measurements, metadata})
        end,
        nil
      )

      {:ok, _pid} = Agent.start_link(id: agent_id)
      {:ok, _response} = Agent.chat(agent_id, "test message")

      # Should receive telemetry event
      assert_receive {:telemetry_response, ^ref, measurements, metadata}, 1000
      assert Map.has_key?(measurements, :duration)
      assert metadata.agent_id == agent_id

      :telemetry.detach("test-agent-response-#{inspect(ref)}")
      Agent.stop(agent_id)
    end
  end

  describe "error monitoring" do
    test "can detect and handle agent errors" do
      # This test would be more meaningful with real LLM integration
      # For now, we test the error handling structure
      agent_id = "error-monitoring-#{:rand.uniform(1000)}"
      {:ok, _pid} = Agent.start_link(id: agent_id)

      # The current placeholder implementation doesn't generate errors
      # In a real implementation, this would test LLM provider failures
      {:ok, _response} = Agent.chat(agent_id, "test message")

      # Agent should still be responsive after any potential errors
      assert :ok = Agent.health_check(agent_id)

      Agent.stop(agent_id)
    end

    test "health check detects unresponsive agents" do
      agent_id = "unresponsive-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Kill the process to simulate unresponsiveness
      Process.exit(pid, :kill)
      Process.sleep(10)

      # Health check should detect the dead agent
      assert {:error, :not_found} = Agent.health_check(agent_id)
    end
  end
end
