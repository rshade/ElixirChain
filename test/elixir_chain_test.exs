defmodule ElixirChainTest do
  @moduledoc """
  Basic tests for the ElixirChain module.
  """

  use ExUnit.Case, async: true

  doctest ElixirChain

  describe "ElixirChain" do
    test "defines version/0" do
      assert is_binary(ElixirChain.version())
      assert ElixirChain.version() =~ ~r/^\d+\.\d+\.\d+/
    end

    test "defines name/0" do
      assert ElixirChain.name() == "ElixirChain"
    end
  end
end
