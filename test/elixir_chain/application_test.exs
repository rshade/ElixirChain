defmodule ElixirChain.ApplicationTest do
  @moduledoc """
  Tests for the ElixirChain.Application module.
  """

  use ExUnit.Case, async: false

  alias ElixirChain.Application

  describe "Application.start/2" do
    test "starts successfully" do
      # The application is already started in test_helper.exs
      # so we just verify it's running
      assert Application.started_applications()
             |> Enum.any?(fn {app, _, _} -> app == :elixir_chain end)
    end

    test "starts required processes" do
      # Verify key processes are running
      assert Process.whereis(ElixirChain.Supervisor)
      assert Registry.whereis_name({ElixirChain.Agent.Registry, :test}) == :undefined
    end
  end

  describe "Application.stop/1" do
    test "defines stop callback" do
      assert :ok = Application.stop(nil)
    end
  end
end
