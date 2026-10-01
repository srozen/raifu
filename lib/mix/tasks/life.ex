defmodule Mix.Tasks.Life do
  @shortdoc "Plays Conway's Game of Life full screen in the terminal"

  @moduledoc """
  Plays Conway's Game of Life full screen in the terminal, every cell of the
  board being its own process.

      $ mix life
      $ mix life --pattern glider_gun --theme aurora
      $ mix life --width 80 --height 40 --bounded --speed 30

  ## Options

    * `--pattern`, `-p` - the seed of the board: #{Enum.map_join(Raifu.Patterns.names(), ", ", &"`#{&1}`")}.
      Defaults to `random`
    * `--density` - the proportion of live cells in a random seed, defaults to `0.35`
    * `--theme`, `-t` - the color theme: #{Enum.map_join(Raifu.Theme.names(), ", ", &"`#{&1}`")}.
      Defaults to `ember`
    * `--speed`, `-s` - milliseconds between two generations, defaults to `100`
    * `--width`, `--height` - the size of the board, in cells. Defaults to
      filling the terminal
    * `--bounded` - cells on the edges have fewer neighbours, instead of the
      board wrapping around like a torus
    * `--paused` - starts paused

  ## Controls

    * `space` - pause / resume
    * `n` or `→` - step one generation
    * `+` / `-` or `↑` / `↓` - faster / slower
    * `p` - next pattern
    * `r` - reseed with the current pattern
    * `t` - next color theme
    * `l` - redraw the screen, after resizing the terminal for instance
    * `?` or `h` - show / hide the controls
    * `q` - quit

  """

  use Mix.Task

  @requirements ["app.start"]

  @switches [
    pattern: :string,
    density: :float,
    theme: :string,
    speed: :integer,
    width: :integer,
    height: :integer,
    bounded: :boolean,
    paused: :boolean
  ]

  @aliases [p: :pattern, t: :theme, s: :speed]

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse!(argv, strict: @switches, aliases: @aliases) do
      {opts, []} ->
        opts |> game_opts() |> Raifu.TUI.run() |> handle_result()

      {_opts, args} ->
        Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}. See: mix help life")
    end
  end

  defp game_opts(opts) do
    Enum.map(opts, fn
      {:pattern, name} -> {:pattern, choose!(name, Raifu.Patterns.names(), "pattern")}
      {:theme, name} -> {:theme, choose!(name, Raifu.Theme.names(), "theme")}
      {:speed, delay} -> {:delay, max(delay, 0)}
      {:bounded, bounded?} -> {:topology, if(bounded?, do: :bounded, else: :torus)}
      option -> option
    end)
  end

  defp choose!(name, choices, kind) do
    Enum.find(choices, &(Atom.to_string(&1) == name)) ||
      Mix.raise("Unknown #{kind} #{inspect(name)}, expected one of: #{Enum.join(choices, ", ")}")
  end

  defp handle_result(:ok), do: :ok

  defp handle_result({:error, :board_too_small}) do
    Mix.raise("The board must be at least 2×2, is the terminal large enough?")
  end

  defp handle_result({:error, {:runner_down, reason}}) do
    Mix.raise("The game crashed: #{inspect(reason)}")
  end

  defp handle_result({:error, reason}) do
    Mix.raise("mix life needs an interactive terminal, got: #{inspect(reason)}")
  end
end
