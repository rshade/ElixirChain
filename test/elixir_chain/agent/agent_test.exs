defmodule ElixirChain.AgentTest do
  @moduledoc """
  Tests for the ElixirChain.Agent GenServer module.
  """

  use ExUnit.Case, async: true

  alias ElixirChain.Agent

  describe "start_link/1" do
    test "starts an agent with required id" do
      opts = [id: "test-agent-#{:rand.uniform(1000)}"]
      assert {:ok, pid} = Agent.start_link(opts)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts an agent with custom configuration" do
      agent_id = "test-agent-#{:rand.uniform(1000)}"

      opts = [
        id: agent_id,
        llm_provider: ElixirChain.LLM.OpenAI,
        tools: [ElixirChain.Tools.Calculator],
        system_prompt: "You are a test assistant.",
        config: %{temperature: 0.7}
      ]

      assert {:ok, pid} = Agent.start_link(opts)
      assert Process.alive?(pid)

      # Verify the agent state was set correctly
      {:ok, state} = Agent.get_state(agent_id)
      assert state.id == agent_id
      assert state.llm_provider == ElixirChain.LLM.OpenAI
      assert state.tools == [ElixirChain.Tools.Calculator]
      assert state.system_prompt == "You are a test assistant."
      assert state.config == %{temperature: 0.7}

      GenServer.stop(pid)
    end

    test "fails without required id" do
      assert_raise KeyError, fn ->
        Agent.start_link([])
      end
    end

    test "prevents duplicate agent ids" do
      agent_id = "duplicate-test-#{:rand.uniform(1000)}"
      opts = [id: agent_id]

      assert {:ok, pid1} = Agent.start_link(opts)
      assert {:error, {:already_started, _pid2}} = Agent.start_link(opts)

      GenServer.stop(pid1)
    end
  end

  describe "get_state/1" do
    test "returns agent state" do
      agent_id = "state-test-#{:rand.uniform(1000)}"
      opts = [id: agent_id, system_prompt: "Test prompt"]

      {:ok, pid} = Agent.start_link(opts)

      assert {:ok, state} = Agent.get_state(agent_id)
      assert state.id == agent_id
      assert state.system_prompt == "Test prompt"
      # default
      assert state.llm_provider == ElixirChain.LLM.Gemini
      # default
      assert state.tools == []
      assert state.memory_pid == nil
      assert is_map(state.config)
      assert is_map(state.conversation_state)

      GenServer.stop(pid)
    end

    test "returns error for non-existent agent" do
      assert {:error, :not_found} = Agent.get_state("non-existent-agent")
    end
  end

  describe "chat/2" do
    test "processes chat message and returns response" do
      agent_id = "chat-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      assert {:ok, response} = Agent.chat(agent_id, "Hello, how are you?")
      assert is_binary(response)
      assert String.contains?(response, "placeholder")

      GenServer.stop(pid)
    end

    test "updates conversation state after chat" do
      agent_id = "conversation-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      message = "Test message"
      {:ok, _response} = Agent.chat(agent_id, message)

      {:ok, state} = Agent.get_state(agent_id)
      messages = state.conversation_state.messages

      assert length(messages) == 1

      assert Enum.any?(messages, fn msg ->
               msg.role == "user" && msg.content == message
             end)

      GenServer.stop(pid)
    end

    test "handles multiple chat messages" do
      agent_id = "multi-chat-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      {:ok, _} = Agent.chat(agent_id, "First message")
      {:ok, _} = Agent.chat(agent_id, "Second message")

      {:ok, state} = Agent.get_state(agent_id)
      messages = state.conversation_state.messages

      assert length(messages) == 2

      GenServer.stop(pid)
    end
  end

  describe "health_check/1" do
    test "returns ok for healthy agent" do
      agent_id = "health-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      assert :ok = Agent.health_check(agent_id)

      GenServer.stop(pid)
    end

    test "returns error for non-existent agent" do
      assert {:error, :not_found} = Agent.health_check("non-existent-agent")
    end
  end

  describe "stop/1" do
    test "stops agent gracefully" do
      agent_id = "stop-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      assert Process.alive?(pid)
      assert :ok = Agent.stop(agent_id)

      # Give it a moment to stop
      Process.sleep(10)
      refute Process.alive?(pid)
    end

    test "returns ok even for non-existent agent" do
      assert :ok = Agent.stop("non-existent-agent")
    end
  end

  describe "process management" do
    test "agent traps exits" do
      agent_id = "trap-exit-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Check if the process is trapping exits
      process_info = Process.info(pid, :trap_exit)
      assert {:trap_exit, true} = process_info

      GenServer.stop(pid)
    end

    test "agent survives linked process exits" do
      agent_id = "survive-test-#{:rand.uniform(1000)}"
      {:ok, agent_pid} = Agent.start_link(id: agent_id)

      # Start a linked process that will exit
      test_pid =
        spawn_link(fn ->
          Process.sleep(50)
          exit(:normal)
        end)

      # Agent should still be alive after linked process exits
      Process.sleep(100)
      assert Process.alive?(agent_pid)

      GenServer.stop(agent_pid)
    end

    test "agent handles unexpected messages gracefully" do
      agent_id = "unexpected-msg-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Send unexpected message
      send(pid, {:unexpected, "message"})

      # Agent should still be responsive
      assert :ok = Agent.health_check(agent_id)

      GenServer.stop(pid)
    end
  end

  describe "initialization" do
    test "initializes with default values" do
      agent_id = "default-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      {:ok, state} = Agent.get_state(agent_id)

      assert state.id == agent_id
      assert state.llm_provider == ElixirChain.LLM.Gemini
      assert state.tools == []
      assert state.memory_pid == nil
      assert state.system_prompt == "You are a helpful AI assistant."
      assert state.config == %{}
      assert state.conversation_state == %{messages: [], context: %{}}

      GenServer.stop(pid)
    end

    test "emits telemetry event on creation" do
      agent_id = "telemetry-test-#{:rand.uniform(1000)}"

      # Attach a test handler
      test_pid = self()
      ref = make_ref()

      :telemetry.attach(
        "test-agent-created",
        [:elixir_chain, :agent, :created],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, ref, measurements, metadata})
        end,
        nil
      )

      {:ok, pid} = Agent.start_link(id: agent_id)

      # Wait for telemetry event
      assert_receive {:telemetry, ^ref, %{count: 1}, metadata}, 1000
      assert metadata.agent_id == agent_id
      assert metadata.llm_provider == ElixirChain.LLM.Gemini

      :telemetry.detach("test-agent-created")
      GenServer.stop(pid)
    end
  end

  describe "code_change/3" do
    test "handles code changes gracefully" do
      agent_id = "code-change-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # Simulate a code change
      old_state = :sys.get_state(pid)
      :sys.suspend(pid)
      :sys.change_code(pid, Agent, "old_version", [])
      :sys.resume(pid)

      # Agent should still be responsive after code change
      assert :ok = Agent.health_check(agent_id)

      GenServer.stop(pid)
    end
  end

  describe "error handling" do
    test "handles chat errors gracefully" do
      agent_id = "error-test-#{:rand.uniform(1000)}"
      {:ok, pid} = Agent.start_link(id: agent_id)

      # For now, the placeholder implementation doesn't throw errors
      # In a real implementation, this would test LLM provider failures
      assert {:ok, _response} = Agent.chat(agent_id, "test message")

      GenServer.stop(pid)
    end
  end
end
