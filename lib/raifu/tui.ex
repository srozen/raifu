defmodule Raifu.TUI do
  @moduledoc """
  A full screen, interactive game in the terminal, as run by `mix life`.

  Puts the terminal in raw mode, starts a game filling the window, then turns
  every key press into a `Raifu.Runner` command until `q` is pressed.
  """

  alias Raifu.{Runner, Terminal}

  @keys %{
    " " => :toggle_pause,
    "n" => :step,
    :right => :step,
    "+" => :faster,
    "=" => :faster,
    :up => :faster,
    "-" => :slower,
    :down => :slower,
    "p" => :next_pattern,
    "r" => :reseed,
    "t" => :next_theme,
    "?" => :toggle_help,
    "h" => :toggle_help,
    "l" => :redraw,
    # Ctrl+L
    "\f" => :redraw
  }

  # q and Ctrl+C, which Terminal.raw_mode/0 turns into a mere key press.
  @quit ["q", "\u0003"]

  @doc """
  Runs the game until the player quits. Takes the options of
  `Raifu.Runner.start_game/3`, plus `:width` and `:height`, which default to
  the size of the terminal.
  """
  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts) do
    with :ok <- Terminal.raw_mode() do
      {columns, rows} = Terminal.size()
      {width, opts} = Keyword.pop(opts, :width, columns)
      {height, opts} = Keyword.pop(opts, :height, (rows - 1) * 2)

      IO.write(Terminal.enter())

      try do
        play(width, height, Keyword.put(opts, :interactive, true))
      after
        Terminal.cooked_mode()
        IO.write(Terminal.leave())
      end
    end
  end

  defp play(width, height, opts) do
    with :ok <- Runner.start_game(width, height, opts) do
      runner = Process.monitor(Runner)
      session = self()
      reader = spawn_link(fn -> read_keys(session) end)

      result = loop(runner)

      Process.unlink(reader)
      Process.exit(reader, :kill)
      stop_game(result)
    end
  end

  defp loop(runner) do
    receive do
      {:key, key} when key in @quit ->
        :ok

      {:key, key} ->
        with {:ok, command} <- Map.fetch(@keys, key), do: Runner.command(command)
        loop(runner)

      :eof ->
        :ok

      {:DOWN, ^runner, :process, _pid, reason} ->
        {:error, {:runner_down, reason}}
    end
  end

  # Waits for the runner to be done with its current frame, so that it does
  # not draw after we leave the alternate screen.
  defp stop_game(:ok), do: Runner.stop_game()
  defp stop_game(error), do: error

  defp read_keys(session) do
    case IO.getn("", 1) do
      "\e" ->
        send(session, {:key, read_escape_sequence()})
        read_keys(session)

      key when is_binary(key) ->
        send(session, {:key, String.downcase(key)})
        read_keys(session)

      _eof_or_error ->
        send(session, :eof)
    end
  end

  defp read_escape_sequence do
    case IO.getn("", 1) do
      "[" ->
        case IO.getn("", 1) do
          "A" -> :up
          "B" -> :down
          "C" -> :right
          "D" -> :left
          _other -> :unknown
        end

      # Escape followed by a regular key: keep the key.
      key ->
        key
    end
  end
end
