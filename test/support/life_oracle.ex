defmodule Raifu.LifeOracle do
  @moduledoc """
  A plain, process free implementation of the Game of Life, written
  independently from `Raifu.Grid` and `Raifu.Cell`, to check the concurrent
  engine and the patterns against.
  """

  @doc "The live cells of the next generation."
  def step(alive, {width, height} = size, topology) do
    for x <- 0..(width - 1)//1,
        y <- 0..(height - 1)//1,
        count = live_neighbours(alive, {x, y}, size, topology),
        count == 3 or (count == 2 and MapSet.member?(alive, {x, y})),
        into: MapSet.new(),
        do: {x, y}
  end

  @doc "The live cells after `generations` generations."
  def run(alive, size, topology, generations) do
    Enum.reduce(1..generations//1, alive, fn _generation, alive -> step(alive, size, topology) end)
  end

  defp live_neighbours(alive, {x, y}, {width, height}, topology) do
    for dx <- -1..1,
        dy <- -1..1,
        {dx, dy} != {0, 0},
        {nx, ny} = {x + dx, y + dy},
        topology == :torus or (nx in 0..(width - 1)//1 and ny in 0..(height - 1)//1),
        MapSet.member?(alive, {Integer.mod(nx, width), Integer.mod(ny, height)}),
        reduce: 0 do
      count -> count + 1
    end
  end
end
