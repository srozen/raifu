defmodule Raifu.BoardTest do
  use ExUnit.Case, async: false

  alias Raifu.{Board, CellSupervisor, LifeOracle, Snapshot}

  setup do
    start_supervised!({Registry, keys: :unique, name: Raifu.CellRegistry})
    start_supervised!(CellSupervisor)
    start_supervised!(Board)
    :ok
  end

  test "a blinker oscillates" do
    :ok = Board.setup(5, 5, pattern: [{1, 2}, {2, 2}, {3, 2}])

    assert %Snapshot{generation: 1, alive: alive} = Board.tick()
    assert alive == MapSet.new([{2, 1}, {2, 2}, {2, 3}])

    assert %Snapshot{generation: 2, alive: alive} = Board.tick()
    assert alive == MapSet.new([{1, 2}, {2, 2}, {3, 2}])
  end

  for topology <- [:bounded, :torus] do
    # Wider than 10 cells on both axes, where cell names used to collide.
    test "evolves a random soup exactly like the oracle on a #{topology} board" do
      size = {23, 17}
      :ok = Board.setup(23, 17, topology: unquote(topology))
      %Snapshot{alive: seed} = Board.snapshot()

      Enum.reduce(1..25, seed, fn generation, previous ->
        expected = LifeOracle.step(previous, size, unquote(topology))
        assert %Snapshot{generation: ^generation, alive: ^expected} = Board.tick()
        expected
      end)
    end
  end

  test "a glider flies around a torus back to where it started" do
    glider = MapSet.new([{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}])
    :ok = Board.setup(8, 8, topology: :torus, pattern: glider)

    # A glider moves by one cell diagonally every four generations.
    snapshot = Enum.reduce(1..32, nil, fn _generation, _snapshot -> Board.tick() end)
    assert %Snapshot{generation: 32, alive: ^glider} = snapshot
  end

  test "setup/3 replaces the previous board" do
    :ok = Board.setup(12, 12)
    assert CellSupervisor.count_cells() == 144

    :ok = Board.setup(3, 4, pattern: [])
    assert CellSupervisor.count_cells() == 12
    assert %Snapshot{size: {3, 4}, generation: 1} = Board.tick()
  end

  test "seed/2 re-seeds the board and starts over from generation 0" do
    :ok = Board.setup(6, 6, pattern: [])
    %Snapshot{generation: 1} = Board.tick()

    block = MapSet.new([{1, 1}, {1, 2}, {2, 1}, {2, 2}])
    :ok = Board.seed(block)

    assert %Snapshot{generation: 0, alive: ^block} = Board.snapshot()
    assert %Snapshot{generation: 1, alive: ^block} = Board.tick()
  end

  test "there is nothing to tick before the first setup" do
    assert Board.tick() == {:error, :no_board}
    assert Board.snapshot() == {:error, :no_board}
    assert Board.seed(:random) == {:error, :no_board}
  end

  test "unknown patterns are rejected" do
    assert_raise ArgumentError, ~r/unknown pattern :nope/, fn ->
      Board.setup(3, 3, pattern: :nope)
    end
  end
end
