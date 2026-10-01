defmodule Raifu.Patterns do
  @moduledoc """
  Ways to seed a board: a random soup or some famous Life patterns.

  Patterns are written in the plaintext format used by the LifeWiki, where
  `O` is a live cell and `.` a dead one.
  """

  alias Raifu.Grid

  @patterns [
    random: "Random soup",
    acorn: "Acorn",
    r_pentomino: "R-pentomino",
    glider_gun: "Gosper glider gun",
    gliders: "Glider rain",
    spaceships: "Spaceship fleet",
    pulsars: "Pulsar field",
    line: "Linear growth",
    diehard: "Diehard",
    pentadecathlon: "Pentadecathlon"
  ]

  @type name ::
          :random
          | :acorn
          | :r_pentomino
          | :glider_gun
          | :gliders
          | :spaceships
          | :pulsars
          | :line
          | :diehard
          | :pentadecathlon
  @type seed :: name() | Enumerable.t(Grid.position())

  @glider """
  .O.
  ..O
  OOO
  """

  @acorn """
  .O.....
  ...O...
  OO..OOO
  """

  @r_pentomino """
  .OO
  OO.
  .O.
  """

  @diehard """
  ......O.
  OO......
  .O...OOO
  """

  @pentadecathlon """
  ..O....O..
  OO.OOOO.OO
  ..O....O..
  """

  @line """
  OOOOOOOO.OOOOO...OOO......OOOOOOO.OOOOO
  """

  @pulsar """
  ..OOO...OOO..
  .............
  O....O.O....O
  O....O.O....O
  O....O.O....O
  ..OOO...OOO..
  .............
  ..OOO...OOO..
  O....O.O....O
  O....O.O....O
  O....O.O....O
  .............
  ..OOO...OOO..
  """

  @glider_gun """
  ........................O...........
  ......................O.O...........
  ............OO......OO............OO
  ...........O...O....OO............OO
  OO........O.....O...OO..............
  OO........O...O.OO....O.O...........
  ..........O.....O.......O...........
  ...........O...O....................
  ............OO......................
  """

  # Light, middle and heavy weight spaceships, all flying west.
  @spaceships [
    """
    .O..O
    O....
    O...O
    OOOO.
    """,
    """
    ...O..
    .O...O
    O.....
    O....O
    OOOOO.
    """,
    """
    ...OO..
    .O....O
    O......
    O.....O
    OOOOOO.
    """
  ]

  @doc "The names of the available patterns, in display order."
  @spec names() :: [name()]
  def names, do: Keyword.keys(@patterns)

  @doc "The human readable name of a pattern."
  @spec label(name()) :: String.t()
  def label(name), do: Keyword.fetch!(@patterns, name)

  @doc "Raises an `ArgumentError` if `seed` is an unknown pattern name."
  @spec validate!(seed()) :: :ok
  def validate!(seed) when is_atom(seed) do
    if Keyword.has_key?(@patterns, seed) do
      :ok
    else
      raise ArgumentError,
            "unknown pattern #{inspect(seed)}, expected one of: #{inspect(names())}"
    end
  end

  def validate!(_cells), do: :ok

  @doc """
  Builds the set of live cells of a board of `size` seeded with `seed`: either
  a pattern name, or any enumerable of positions. Cells falling outside of the
  board are dropped.

  ## Options

    * `:density` - the probability for each cell of a `:random` seed to be
      alive. Defaults to `0.35`.

  """
  @spec seed(seed(), Grid.size(), keyword()) :: MapSet.t(Grid.position())
  def seed(seed, size, opts \\ [])

  def seed(name, size, opts) when is_atom(name) do
    validate!(name)
    name |> cells(size, opts) |> clip(size)
  end

  def seed(cells, size, _opts), do: clip(cells, size)

  defp cells(:random, size, opts) do
    density = Keyword.get(opts, :density, 0.35)
    for position <- Grid.positions(size), :rand.uniform() < density, do: position
  end

  defp cells(:acorn, size, _opts), do: centered(@acorn, size)
  defp cells(:r_pentomino, size, _opts), do: centered(@r_pentomino, size)
  defp cells(:diehard, size, _opts), do: centered(@diehard, size)
  defp cells(:pentadecathlon, size, _opts), do: centered(@pentadecathlon, size)
  defp cells(:line, size, _opts), do: centered(@line, size)
  defp cells(:glider_gun, _size, _opts), do: @glider_gun |> parse() |> translate({2, 2})

  # Gliders scattered on a coarse grid, flying in all four directions.
  defp cells(:gliders, {width, height}, _opts) do
    glider = parse(@glider)

    for bx <- 0..(div(width, 12) - 1)//1,
        by <- 0..(div(height, 12) - 1)//1,
        :rand.uniform() < 0.4,
        offset = {bx * 12 + :rand.uniform(9) - 1, by * 12 + :rand.uniform(9) - 1},
        cell <- glider |> flip(Enum.random([:none, :x, :y, :xy])) |> translate(offset),
        do: cell
  end

  # One ship per lane, staggered, all heading west from the east side.
  defp cells(:spaceships, {width, height}, _opts) do
    ships = Enum.map(@spaceships, &parse/1)

    for lane <- 0..(div(height - 2, 8) - 1)//1,
        offset = {width - 10 - rem(lane * 13, 29), 2 + lane * 8},
        cell <- ships |> Enum.at(rem(lane, 3)) |> translate(offset),
        do: cell
  end

  defp cells(:pulsars, {width, height}, _opts) do
    pulsar = parse(@pulsar)
    {xs, ys} = {tiles(width, 13, 18), tiles(height, 13, 18)}

    for x <- xs, y <- ys, cell <- translate(pulsar, {x, y}), do: cell
  end

  # Offsets of as many `tile`-wide tiles, `step` apart, as fit centered in `length`.
  defp tiles(length, tile, step) do
    count = max(div(length - tile, step) + 1, 1)
    start = div(length - ((count - 1) * step + tile), 2)
    for index <- 0..(count - 1), do: start + index * step
  end

  defp parse(text) do
    for {line, y} <- text |> String.split("\n", trim: true) |> Enum.with_index(),
        {char, x} <- line |> String.to_charlist() |> Enum.with_index(),
        char == ?O,
        do: {x, y}
  end

  defp centered(text, {width, height}) do
    cells = parse(text)
    {pattern_width, pattern_height} = dimensions(cells)
    translate(cells, {div(width - pattern_width, 2), div(height - pattern_height, 2)})
  end

  defp dimensions(cells) do
    {Enum.max(Enum.map(cells, &elem(&1, 0))) + 1, Enum.max(Enum.map(cells, &elem(&1, 1))) + 1}
  end

  defp translate(cells, {dx, dy}), do: Enum.map(cells, fn {x, y} -> {x + dx, y + dy} end)

  defp flip(cells, :none), do: cells

  defp flip(cells, axis) do
    {width, height} = dimensions(cells)

    Enum.map(cells, fn {x, y} ->
      case axis do
        :x -> {width - 1 - x, y}
        :y -> {x, height - 1 - y}
        :xy -> {width - 1 - x, height - 1 - y}
      end
    end)
  end

  defp clip(cells, size) do
    for cell <- cells, Grid.locate(cell, size, :bounded) != nil, into: MapSet.new(), do: cell
  end
end
