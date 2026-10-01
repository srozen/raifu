defmodule Raifu.PatternsTest do
  use ExUnit.Case, async: true

  alias Raifu.{LifeOracle, Patterns}

  test "every pattern seeds a board within its bounds" do
    for name <- Patterns.names(), size <- [{7, 5}, {200, 90}] do
      {width, height} = size

      for {x, y} <- Patterns.seed(name, size) do
        assert x in 0..(width - 1) and y in 0..(height - 1)
      end

      assert is_binary(Patterns.label(name))
    end
  end

  test "any enumerable of positions is a seed, clipped to the board" do
    assert Patterns.seed([{0, 0}, {2, 1}, {5, 5}, {-1, 0}], {3, 3}) ==
             MapSet.new([{0, 0}, {2, 1}])
  end

  test "a random seed follows the requested density" do
    assert Patterns.seed(:random, {10, 10}, density: 0.0) == MapSet.new()
    assert MapSet.size(Patterns.seed(:random, {10, 10}, density: 1.0)) == 100
  end

  test "validate!/1 rejects unknown pattern names" do
    assert Patterns.validate!(:acorn) == :ok
    assert Patterns.validate!([{0, 0}]) == :ok
    assert_raise ArgumentError, fn -> Patterns.validate!(:nope) end
  end

  describe "famous patterns behave as expected" do
    test "diehard vanishes after exactly 130 generations" do
      size = {50, 50}
      seed = Patterns.seed(:diehard, size)

      assert seed |> LifeOracle.run(size, :bounded, 129) |> MapSet.size() > 0
      assert seed |> LifeOracle.run(size, :bounded, 130) |> MapSet.size() == 0
    end

    test "the glider gun fires a glider every 30 generations" do
      size = {100, 100}
      seed = Patterns.seed(:glider_gun, size)

      populations =
        for generation <- [0, 30, 60] do
          seed |> LifeOracle.run(size, :bounded, generation) |> MapSet.size()
        end

      assert populations == [36, 41, 46]
    end

    test "pulsars oscillate with period 3" do
      size = {60, 40}
      seed = Patterns.seed(:pulsars, size)

      assert LifeOracle.run(seed, size, :bounded, 3) == seed
      refute LifeOracle.run(seed, size, :bounded, 1) == seed
    end

    test "spaceships fly west, two cells every four generations" do
      size = {80, 40}
      seed = Patterns.seed(:spaceships, size)
      moved = MapSet.new(seed, fn {x, y} -> {x - 2, y} end)

      assert LifeOracle.run(seed, size, :bounded, 4) == moved
    end
  end
end
