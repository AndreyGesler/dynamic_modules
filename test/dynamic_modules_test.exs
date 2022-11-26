defmodule DynamicModulesTest do
  use ExUnit.Case
  doctest DynamicModules

  test "greets the world" do
    assert DynamicModules.ping() == :pong
  end
end
