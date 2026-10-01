defmodule Raifu.Renderer do
  @moduledoc """
  Draws a `Raifu.View` as a full terminal frame.

  Every character of the terminal shows two cells of the board, stacked: an
  upper half block `▀` painted with the top cell as foreground color and the
  bottom cell as background color. Cells come out square, and the terminal
  fits twice as many of them.

  The last line of the terminal holds a status bar.
  """

  alias Raifu.{Terminal, Theme, View}

  @typedoc "What the frame shows besides the view itself."
  @type hud :: %{
          status: :running | :paused,
          pattern: String.t(),
          rate: float(),
          tick_ms: float(),
          interactive: boolean(),
          help: boolean()
        }

  @half_block "▀"
  @sparks ~w(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  @sparkline 16
  @gap "  "

  @help [
    {"space", "pause / play"},
    {"n →", "step one generation"},
    {"+ - ↑ ↓", "faster / slower"},
    {"p", "next pattern"},
    {"r", "reseed the pattern"},
    {"t", "next theme"},
    {"l", "redraw the screen"},
    {"?", "close this help"},
    {"q", "quit"}
  ]
  @help_width 36

  @doc "Draws the whole frame for a terminal of `{columns, rows}`."
  @spec frame(View.t(), Theme.palette(), hud(), {pos_integer(), pos_integer()}) :: iodata()
  def frame(%View{} = view, palette, hud, {columns, rows}) do
    Terminal.synchronized([
      board(view, palette, {columns, rows - 1}),
      if(hud.help, do: help(palette, {columns, rows - 1}), else: []),
      Terminal.move(rows, 1),
      status_bar(view, palette, hud, columns),
      Terminal.reset()
    ])
  end

  ## Board

  defp board(%View{size: {width, height}} = view, palette, {columns, lines}) do
    # Center the board, or show its top left corner when it does not fit.
    left = max(div(columns - width, 2), 0)
    top = max(div(lines - div(height + 1, 2), 2), 0)

    for line <- 0..(lines - 1)//1 do
      [Terminal.move(line + 1, 1), row(view, palette, (line - top) * 2, left, columns)]
    end
  end

  defp row(view, palette, y, left, columns) do
    {codes, _fg, _bg} =
      Enum.reduce(0..(columns - 1)//1, {[], nil, nil}, fn column, {codes, fg, bg} ->
        upper = color(view, palette, {column - left, y})
        lower = color(view, palette, {column - left, y + 1})

        if upper == lower do
          # A space only shows its background.
          {[" ", set(:bg, palette, bg, lower) | codes], fg, lower}
        else
          {[@half_block, set(:bg, palette, bg, lower), set(:fg, palette, fg, upper) | codes],
           upper, lower}
        end
      end)

    Enum.reverse(codes)
  end

  defp set(_layer, _palette, current, current), do: []
  defp set(:fg, palette, _current, color), do: Theme.fg(palette, color)
  defp set(:bg, palette, _current, color), do: Theme.bg(palette, color)

  defp color(%View{size: {width, height}} = view, palette, {x, y} = position)
       when x >= 0 and x < width and y >= 0 and y < height do
    case view do
      %{ages: %{^position => age}} -> Theme.life(palette, age)
      %{ghosts: %{^position => fade}} -> Theme.trail(palette, fade)
      _dead -> palette.background
    end
  end

  defp color(_view, palette, _off_board), do: palette.void

  ## Help

  defp help(palette, {columns, lines}) do
    inner = @help_width - 2
    title = " controls "
    side = div(inner - String.length(title), 2)

    entries =
      for {keys, action} <- @help do
        [
          {:dim, "│  "},
          {:key, String.pad_trailing(keys, 10)},
          {:text, String.pad_trailing(action, inner - 12)},
          {:dim, "│"}
        ]
      end

    blank = [{:dim, "│" <> String.duplicate(" ", inner) <> "│"}]

    box =
      [
        [
          {:dim, "╭" <> String.duplicate("─", side)},
          {:accent, title},
          {:dim, String.duplicate("─", inner - side - String.length(title)) <> "╮"}
        ],
        blank
      ] ++ entries ++ [blank, [{:dim, "╰" <> String.duplicate("─", inner) <> "╯"}]]

    top = max(div(lines - length(box), 2), 0) + 1
    left = max(div(columns - @help_width, 2), 0) + 1

    for {parts, row} <- Enum.with_index(box, top) do
      [Terminal.move(row, left), Enum.map(parts, &part(&1, palette))]
    end
  end

  ## Status bar

  defp status_bar(view, palette, hud, columns) do
    # Leave the very last column alone: writing there could scroll the screen.
    {right, left} =
      view
      |> segments(hud, columns - 1)
      |> Enum.split_with(&match?({_priority, :right, _parts}, &1))

    left = left |> Enum.map(&elem(&1, 2)) |> Enum.intersperse([{:text, @gap}]) |> Enum.concat()
    right = Enum.flat_map(right, &elem(&1, 2))
    padding = max(columns - 1 - width(left) - width(right), 0)

    [
      Enum.map(left, &part(&1, palette)),
      part({:text, String.duplicate(" ", padding)}, palette),
      Enum.map(right, &part(&1, palette)),
      Terminal.clear_line()
    ]
  end

  # Segments are {priority, alignment, parts}: the lowest priorities are the
  # first to go when the terminal is too narrow. The keyboard controls come in
  # full when there is room for them, as a hint to the help otherwise.
  defp segments(view, %{interactive: false} = hud, width) do
    view |> stats(hud) |> fit(width)
  end

  defp segments(view, hud, width) do
    stats = stats(view, hud)
    full = fit([{25, :right, keys(hud.status)} | stats], width)

    if Enum.any?(full, &match?({_priority, :right, _parts}, &1)) do
      full
    else
      fit([{75, :right, [{:key, "?"}, {:dim, " help "}]} | stats], width)
    end
  end

  defp stats(view, hud) do
    {width, height} = view.size

    [
      {100, :left, [{:brand, " RAIFU "}, {:accent, status_icon(hud.status)}]},
      {90, :left, [{:dim, "gen "}, {:text, pad(delimit(view.generation), 6)}]},
      {90, :left, [{:dim, "pop "}, {:text, pad(delimit(view.population), 6)}]},
      {50, :left, [{:accent, sparkline(view.history)}]},
      {60, :left,
       [
         {:births, pad("+" <> delimit(view.births), 5)},
         {:deaths, pad("−" <> delimit(view.deaths), 5)}
       ]},
      {85, :left, outcome(View.outcome(view))},
      {80, :left, [{:text, hud.pattern}]},
      {30, :left, [{:dim, "#{view.topology} "}, {:text, "#{width}×#{height}"}]},
      {20, :left, [{:text, delimit(width * height)}, {:dim, " cells"}]},
      {70, :left, rate(hud)},
      {10, :left, [{:text, :erlang.float_to_binary(hud.tick_ms, decimals: 1)}, {:dim, " ms/gen"}]}
    ]
    |> Enum.reject(&match?({_priority, _alignment, []}, &1))
  end

  defp fit(segments, width) do
    if length(segments) <= 1 or total_width(segments) <= width do
      segments
    else
      fit(List.delete(segments, Enum.min_by(segments, &elem(&1, 0))), width)
    end
  end

  defp total_width(segments) do
    gaps = String.length(@gap) * (length(segments) - 1)
    Enum.sum_by(segments, fn {_priority, _alignment, parts} -> width(parts) end) + gaps
  end

  defp width(parts), do: Enum.sum_by(parts, fn {_style, text} -> String.length(text) end)

  defp part({:brand, text}, palette) do
    ["\e[1m", Theme.bg(palette, palette.accent), Theme.fg(palette, palette.background), text]
  end

  defp part({style, text}, palette) do
    color =
      case style do
        :text -> palette.text
        :dim -> palette.dim
        :accent -> palette.accent
        :key -> palette.accent
        :births -> Theme.life(palette, 2)
        :deaths -> Theme.life(palette, 16)
      end

    ["\e[22m", Theme.bg(palette, palette.panel), Theme.fg(palette, color), text]
  end

  defp status_icon(:running), do: " ▶"
  defp status_icon(:paused), do: " ❚❚"

  defp outcome(:extinct), do: [{:accent, "extinct"}]
  defp outcome(:still), do: [{:accent, "still life"}]
  defp outcome({:oscillating, period}), do: [{:accent, "period #{period}"}]
  defp outcome(nil), do: []

  defp rate(%{status: :paused}), do: [{:dim, "paused"}]

  defp rate(%{rate: rate}) do
    [{:text, :erlang.float_to_binary(rate, decimals: 1)}, {:dim, " gen/s"}]
  end

  defp keys(status) do
    [
      {:key, "space"},
      {:dim, if(status == :paused, do: " play  ", else: " pause  ")},
      {:key, "n"},
      {:dim, " step  "},
      {:key, "+/-"},
      {:dim, " speed  "},
      {:key, "p"},
      {:dim, " pattern  "},
      {:key, "t"},
      {:dim, " theme  "},
      {:key, "?"},
      {:dim, " help  "},
      {:key, "q"},
      {:dim, " quit "}
    ]
  end

  defp sparkline(history) do
    values = history |> Enum.take(@sparkline) |> Enum.reverse()
    {low, high} = Enum.min_max(values)

    values
    |> Enum.map_join(fn
      _value when high == low -> Enum.at(@sparks, 3)
      value -> Enum.at(@sparks, div((value - low) * 7, high - low))
    end)
    |> pad(@sparkline)
  end

  defp pad(text, width), do: String.pad_trailing(text, width)

  defp delimit(integer) do
    integer |> Integer.to_string() |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end
end
