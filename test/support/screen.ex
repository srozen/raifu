defmodule Raifu.Screen do
  @moduledoc """
  A tiny terminal emulator, just enough to check what the renderer draws: it
  understands cursor moves and colors, and ignores every other sequence.
  """

  @doc """
  Plays `output` and returns the screen as a map of `{row, column}` (starting
  at 1) to `{character, foreground, background}`, colors being RGB tuples.
  """
  def play(output) do
    output
    |> IO.chardata_to_string()
    |> String.split(~r/(?=\e\[)/)
    |> Enum.reduce({%{}, {1, 1}, nil, nil}, &play_chunk/2)
    |> elem(0)
  end

  @doc "The characters of `row`, from `first` to `last` column."
  def text(screen, row, first, last) do
    Enum.map_join(first..last, fn column ->
      case screen do
        %{{^row, ^column} => {char, _fg, _bg}} -> char
        _blank -> " "
      end
    end)
  end

  @doc "Removes every escape sequence from `output`."
  def strip(output) do
    output |> IO.chardata_to_string() |> String.replace(~r/\e\[[0-9;?]*[a-zA-Z]/, "")
  end

  defp play_chunk(chunk, {screen, cursor, fg, bg}) do
    case Regex.run(~r/\A\e\[([0-9;?]*)([a-zA-Z])(.*)\z/s, chunk) do
      [_chunk, params, "H", text] ->
        [row, column] = params |> String.split(";") |> Enum.map(&String.to_integer/1)
        write(text, {screen, {row, column}, fg, bg})

      [_chunk, params, "m", text] ->
        {fg, bg} = sgr(String.split(params, ";"), {fg, bg})
        write(text, {screen, cursor, fg, bg})

      [_chunk, _params, _command, text] ->
        write(text, {screen, cursor, fg, bg})

      nil ->
        write(chunk, {screen, cursor, fg, bg})
    end
  end

  defp write(text, state) do
    text
    |> String.graphemes()
    |> Enum.reduce(state, fn char, {screen, {row, column}, fg, bg} ->
      {Map.put(screen, {row, column}, {char, fg, bg}), {row, column + 1}, fg, bg}
    end)
  end

  defp sgr(["38", "2", r, g, b | rest], {_fg, bg}), do: sgr(rest, {rgb(r, g, b), bg})
  defp sgr(["48", "2", r, g, b | rest], {fg, _bg}), do: sgr(rest, {fg, rgb(r, g, b)})
  defp sgr(["0" | rest], _colors), do: sgr(rest, {nil, nil})
  defp sgr([_other | rest], colors), do: sgr(rest, colors)
  defp sgr([], colors), do: colors

  defp rgb(r, g, b), do: {String.to_integer(r), String.to_integer(g), String.to_integer(b)}
end
