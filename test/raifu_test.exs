defmodule RaifuTest do
  use ExUnit.Case
  doctest Raifu

  test "greets the world" do
    assert Raifu.hello() == :world
  end
end
