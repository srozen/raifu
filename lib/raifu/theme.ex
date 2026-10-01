defmodule Raifu.Theme do
  @moduledoc """
  Color themes and the terminal escape codes they turn into.

  A live cell is colored after its age: newborns glow with the first color of
  the theme's `:life` gradient and slowly cool down to its last color as they
  get older, so still lifes stand out from the chaos. Dead cells leave a trail
  fading from the `:trail` color into the background.
  """

  @type rgb :: {0..255, 0..255, 0..255}
  @type depth :: :truecolor | :ansi256
  @type name :: :ember | :aurora | :neon | :matrix | :paper

  @typedoc "A theme resolved for a color depth, ready for rendering."
  @type palette :: %{
          name: name(),
          background: rgb(),
          void: rgb(),
          panel: rgb(),
          text: rgb(),
          dim: rgb(),
          accent: rgb(),
          life: tuple(),
          trail: tuple(),
          codes: %{rgb() => {fg :: iodata(), bg :: iodata()}}
        }

  # Past this age, cells keep the last color of the gradient.
  @max_age 64

  @themes [
    ember: %{
      background: {14, 10, 16},
      void: {6, 4, 8},
      panel: {34, 22, 34},
      text: {240, 226, 214},
      dim: {150, 118, 126},
      accent: {255, 176, 64},
      trail: {130, 34, 52},
      life: [
        {255, 252, 232},
        {255, 222, 110},
        {255, 150, 52},
        {232, 68, 58},
        {170, 34, 96},
        {92, 30, 118}
      ]
    },
    aurora: %{
      background: {6, 12, 22},
      void: {2, 5, 10},
      panel: {16, 30, 48},
      text: {220, 238, 245},
      dim: {110, 145, 165},
      accent: {110, 240, 200},
      trail: {22, 70, 96},
      life: [
        {236, 255, 250},
        {130, 255, 206},
        {56, 206, 222},
        {66, 128, 236},
        {112, 76, 214},
        {72, 44, 140}
      ]
    },
    neon: %{
      background: {14, 6, 26},
      void: {6, 2, 12},
      panel: {36, 16, 60},
      text: {245, 230, 255},
      dim: {150, 120, 180},
      accent: {255, 92, 200},
      trail: {80, 20, 96},
      life: [
        {255, 255, 255},
        {255, 120, 210},
        {196, 92, 255},
        {92, 118, 255},
        {40, 200, 255},
        {24, 70, 150}
      ]
    },
    matrix: %{
      background: {2, 10, 5},
      void: {0, 4, 2},
      panel: {8, 28, 14},
      text: {200, 255, 210},
      dim: {90, 160, 110},
      accent: {90, 255, 130},
      trail: {12, 60, 28},
      life: [
        {225, 255, 225},
        {110, 255, 140},
        {40, 210, 90},
        {24, 150, 64},
        {14, 96, 44}
      ]
    },
    paper: %{
      background: {244, 238, 226},
      void: {226, 218, 202},
      panel: {226, 216, 198},
      text: {40, 36, 46},
      dim: {120, 110, 104},
      accent: {196, 64, 44},
      trail: {214, 196, 176},
      life: [
        {214, 58, 40},
        {186, 64, 60},
        {96, 70, 90},
        {40, 44, 64},
        {22, 24, 34}
      ]
    }
  ]

  @doc "The names of the available themes, in display order."
  @spec names() :: [name()]
  def names, do: Keyword.keys(@themes)

  @doc "The age from which a cell no longer changes color."
  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  @doc """
  The color depth supported by the terminal, as advertised by `$COLORTERM`.
  """
  @spec detect_depth() :: depth()
  def detect_depth do
    if System.get_env("COLORTERM") in ["truecolor", "24bit"], do: :truecolor, else: :ansi256
  end

  @doc """
  Resolves the theme `name` for the given color `depth`, with a trail of
  `trail` generations.
  """
  @spec palette(name(), depth(), pos_integer()) :: palette()
  def palette(name, depth, trail) do
    theme = Keyword.fetch!(@themes, name)

    life = for age <- 1..@max_age, do: gradient(theme.life, age_ratio(age))

    trail =
      for fade <- 1..trail do
        # Ease out, so the trail dims quickly and then lingers.
        blend(theme.trail, theme.background, 1 - :math.pow(1 - fade / (trail + 1), 2))
      end

    colors =
      [theme.background, theme.void, theme.panel, theme.text, theme.dim, theme.accent] ++
        life ++ trail

    theme
    |> Map.take([:background, :void, :panel, :text, :dim, :accent])
    |> Map.merge(%{
      name: name,
      life: List.to_tuple(life),
      trail: List.to_tuple(trail),
      codes: Map.new(colors, &{&1, {sgr(38, &1, depth), sgr(48, &1, depth)}})
    })
  end

  @doc "The color of a cell alive for `age` generations."
  @spec life(palette(), pos_integer()) :: rgb()
  def life(palette, age), do: elem(palette.life, min(age, @max_age) - 1)

  @doc "The color of a cell dead for `fade` generations."
  @spec trail(palette(), pos_integer()) :: rgb()
  def trail(palette, fade), do: elem(palette.trail, fade - 1)

  @doc "The escape codes setting `color` as foreground."
  @spec fg(palette(), rgb()) :: iodata()
  def fg(palette, color), do: palette.codes |> Map.fetch!(color) |> elem(0)

  @doc "The escape codes setting `color` as background."
  @spec bg(palette(), rgb()) :: iodata()
  def bg(palette, color), do: palette.codes |> Map.fetch!(color) |> elem(1)

  @doc """
  The xterm 256 colors index closest to an RGB color.

      iex> Raifu.Theme.ansi256({255, 0, 0})
      196
      iex> Raifu.Theme.ansi256({128, 128, 128})
      244
  """
  @spec ansi256(rgb()) :: 16..255
  def ansi256({r, g, b} = color) do
    levels = [0, 95, 135, 175, 215, 255]
    {ri, gi, bi} = {cube_index(r), cube_index(g), cube_index(b)}
    cube = {Enum.at(levels, ri), Enum.at(levels, gi), Enum.at(levels, bi)}

    gray_index = round(((r + g + b) / 3 - 8) / 10) |> max(0) |> min(23)
    gray_level = 8 + gray_index * 10

    if distance(color, {gray_level, gray_level, gray_level}) < distance(color, cube) do
      232 + gray_index
    else
      16 + 36 * ri + 6 * gi + bi
    end
  end

  defp cube_index(value) when value < 48, do: 0
  defp cube_index(value) when value < 115, do: 1
  defp cube_index(value), do: div(value - 35, 40)

  defp distance({r1, g1, b1}, {r2, g2, b2}) do
    (r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2
  end

  defp sgr(layer, {r, g, b}, :truecolor), do: "\e[#{layer};2;#{r};#{g};#{b}m"
  defp sgr(layer, color, :ansi256), do: "\e[#{layer};5;#{ansi256(color)}m"

  # Ages grow on a log scale: young cells change color every generation, old
  # ones barely do.
  defp age_ratio(age), do: min(:math.log(age) / :math.log(@max_age), 1.0)

  defp gradient(stops, ratio) do
    position = ratio * (length(stops) - 1)
    index = min(trunc(position), length(stops) - 2)
    blend(Enum.at(stops, index), Enum.at(stops, index + 1), position - index)
  end

  defp blend({r1, g1, b1}, {r2, g2, b2}, ratio) do
    {mix(r1, r2, ratio), mix(g1, g2, ratio), mix(b1, b2, ratio)}
  end

  defp mix(from, to, ratio), do: round(from + (to - from) * ratio)
end
