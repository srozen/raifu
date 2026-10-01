defmodule Raifu.Grid do
  @moduledoc """
  Pure geometry of the board: positions and neighbourhoods.

  A board of `{width, height}` holds the positions `{0, 0}` to
  `{width - 1, height - 1}`. Its topology is either `:bounded` (cells on the
  edges have fewer neighbours) or `:torus` (edges wrap around, so gliders
  leaving on the right come back on the left).
  """

  @type position :: {x :: non_neg_integer(), y :: non_neg_integer()}
  @type size :: {width :: pos_integer(), height :: pos_integer()}
  @type topology :: :bounded | :torus

  @offsets for dy <- -1..1, dx <- -1..1, {dx, dy} != {0, 0}, do: {dx, dy}

  @doc """
  Lists every position of the board, row by row.

      iex> Raifu.Grid.positions({2, 2})
      [{0, 0}, {1, 0}, {0, 1}, {1, 1}]
  """
  @spec positions(size()) :: [position()]
  def positions({width, height}) do
    for y <- 0..(height - 1)//1, x <- 0..(width - 1)//1, do: {x, y}
  end

  @doc """
  Lists the neighbours of `position`.

  On a torus smaller than 3×3 the same cell can be a neighbour several times
  over (or a neighbour of itself): it is then listed as many times, which is
  exactly how it counts in the rules.

      iex> Raifu.Grid.neighbors({0, 0}, {3, 3}, :bounded)
      [{1, 0}, {0, 1}, {1, 1}]
  """
  @spec neighbors(position(), size(), topology()) :: [position()]
  def neighbors({x, y}, size, topology) do
    Enum.flat_map(@offsets, fn {dx, dy} ->
      case locate({x + dx, y + dy}, size, topology) do
        nil -> []
        neighbor -> [neighbor]
      end
    end)
  end

  @doc """
  Maps any coordinates to a position of the board, or `nil` when they fall off
  a bounded board.

      iex> Raifu.Grid.locate({-1, 3}, {3, 3}, :torus)
      {2, 0}
      iex> Raifu.Grid.locate({-1, 3}, {3, 3}, :bounded)
      nil
  """
  @spec locate({integer(), integer()}, size(), topology()) :: position() | nil
  def locate({x, y}, {width, height}, :torus) do
    {Integer.mod(x, width), Integer.mod(y, height)}
  end

  def locate({x, y}, {width, height}, :bounded)
      when x >= 0 and x < width and y >= 0 and y < height,
      do: {x, y}

  def locate(_coordinates, _size, :bounded), do: nil
end
