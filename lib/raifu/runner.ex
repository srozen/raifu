defmodule Raifu.Runner do
  @moduledoc """
  Plays the game: ticks the board at a steady pace and draws every generation
  on the terminal.

  From `iex -S mix`:

      Raifu.Runner.start_game(60, 40, pattern: :acorn)
      Raifu.Runner.command(:pause)
      Raifu.Runner.stop_game()

  `mix life` wraps it in a full screen session controlled with the keyboard.
  """

  use GenServer

  alias Raifu.{Board, Patterns, Renderer, Snapshot, Terminal, Theme, View}

  # Milliseconds between two generations, from slowest to fastest.
  @delays [1000, 500, 250, 150, 100, 60, 30, 15, 0]

  @commands [
    :pause,
    :resume,
    :toggle_pause,
    :step,
    :faster,
    :slower,
    :reseed,
    :next_pattern,
    :next_theme,
    :toggle_help,
    :redraw
  ]

  @type command ::
          :pause
          | :resume
          | :toggle_pause
          | :step
          | :faster
          | :slower
          | :reseed
          | :next_pattern
          | :next_theme
          | :toggle_help
          | :redraw

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a game on a new `width × height` board, replacing the current one.

  ## Options

    * `:pattern` - how to seed the board, see `Raifu.Patterns`. Defaults to
      `:random`
    * `:density` - the density of a `:random` seed
    * `:topology` - `:torus` (default) or `:bounded`
    * `:theme` - one of `Raifu.Theme.names/0`, defaults to `:ember`
    * `:depth` - `:truecolor` or `:ansi256`, detected by default
    * `:delay` - milliseconds between two generations, defaults to `100`
    * `:paused` - whether to start paused, defaults to `false`
    * `:interactive` - whether to show the keyboard controls, defaults to `false`
    * `:device` - the IO device to draw on, defaults to `:stdio`

  """
  @spec start_game(pos_integer(), pos_integer(), keyword()) :: :ok | {:error, term()}
  def start_game(width, height, opts \\ [])

  def start_game(width, height, _opts) when width < 2 or height < 2 do
    {:error, :board_too_small}
  end

  def start_game(width, height, opts) do
    Patterns.validate!(Keyword.get(opts, :pattern, :random))
    theme = Keyword.get(opts, :theme, :ember)

    if theme not in Theme.names() do
      raise ArgumentError,
            "unknown theme #{inspect(theme)}, expected one of: #{inspect(Theme.names())}"
    end

    GenServer.call(__MODULE__, {:start, {width, height}, opts}, :timer.seconds(30))
  end

  @doc """
  Stops the game in progress, if any. Returns once the frame being drawn, if
  any, is done.
  """
  @spec stop_game() :: :ok
  def stop_game, do: GenServer.call(__MODULE__, :stop)

  @doc """
  Controls the game in progress:

    * `:pause`, `:resume` and `:toggle_pause`
    * `:step` - pauses, then moves on by a single generation
    * `:faster` and `:slower`
    * `:reseed` - seeds the board again with the current pattern
    * `:next_pattern` - seeds the board with the next pattern
    * `:next_theme` - switches to the next color theme
    * `:toggle_help` - shows or hides the keyboard controls
    * `:redraw` - clears the terminal and draws the board again

  """
  @spec command(command()) :: :ok
  def command(command) when command in @commands do
    GenServer.cast(__MODULE__, {:command, command})
  end

  ## Implementation

  @impl GenServer
  def init(_opts), do: {:ok, %{status: :idle}}

  @impl GenServer
  def handle_call({:start, {width, height}, opts}, _from, state) do
    pattern = Keyword.get(opts, :pattern, :random)
    seed_opts = Keyword.take(opts, [:density])
    board_opts = [topology: Keyword.get(opts, :topology, :torus), pattern: pattern] ++ seed_opts

    with :ok <- Board.setup(width, height, board_opts),
         %Snapshot{} = snapshot <- Board.snapshot() do
      depth = Keyword.get_lazy(opts, :depth, &Theme.detect_depth/0)
      theme = Keyword.get(opts, :theme, :ember)

      game = %{
        status: if(Keyword.get(opts, :paused, false), do: :paused, else: :running),
        view: View.new(snapshot),
        pattern: pattern,
        seed_opts: seed_opts,
        theme: theme,
        depth: depth,
        palette: Theme.palette(theme, depth, View.trail()),
        delay: Keyword.get(opts, :delay, 100),
        interactive: Keyword.get(opts, :interactive, false),
        help: false,
        device: Keyword.get(opts, :device, :stdio),
        timer: nil,
        screen: nil,
        rate: 0.0,
        tick_ms: 0.0,
        last_tick: nil
      }

      {:reply, :ok, game |> draw() |> schedule(0)}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call(:stop, _from, _state), do: {:reply, :ok, %{status: :idle}}

  @impl GenServer
  def handle_cast({:command, _command}, %{status: :idle} = state), do: {:noreply, state}
  def handle_cast({:command, command}, game), do: {:noreply, run(command, game)}

  @impl GenServer
  def handle_info({:tick, timer}, %{status: :running, timer: timer} = game) do
    started = System.monotonic_time(:millisecond)
    game = game |> advance() |> draw()
    spent = System.monotonic_time(:millisecond) - started

    {:noreply, schedule(game, max(game.delay - spent, 0))}
  end

  # A tick scheduled before a pause or a new game.
  def handle_info({:tick, _stale_timer}, state), do: {:noreply, state}

  defp run(:pause, %{status: :running} = game), do: draw(%{game | status: :paused})

  defp run(:resume, %{status: :paused} = game) do
    %{game | status: :running, last_tick: nil} |> draw() |> schedule(0)
  end

  defp run(:toggle_pause, %{status: :running} = game), do: run(:pause, game)
  defp run(:toggle_pause, %{status: :paused} = game), do: run(:resume, game)
  defp run(:step, game), do: %{game | status: :paused} |> advance() |> draw()
  defp run(:faster, game), do: draw(%{game | delay: Enum.find(@delays, 0, &(&1 < game.delay))})

  defp run(:slower, game) do
    slower = @delays |> Enum.reverse() |> Enum.find(hd(@delays), &(&1 > game.delay))
    draw(%{game | delay: slower})
  end

  defp run(:reseed, game), do: reseed(game, game.pattern)
  defp run(:next_pattern, game), do: reseed(game, next(Patterns.names(), game.pattern))

  defp run(:next_theme, game) do
    theme = next(Theme.names(), game.theme)
    draw(%{game | theme: theme, palette: Theme.palette(theme, game.depth, View.trail())})
  end

  defp run(:toggle_help, game), do: draw(%{game | help: not game.help})
  defp run(:redraw, game), do: draw(%{game | screen: nil})

  # Pausing a paused game and the like.
  defp run(_command, game), do: game

  defp reseed(game, pattern) do
    :ok = Board.seed(pattern, game.seed_opts)
    %Snapshot{} = snapshot = Board.snapshot()
    draw(%{game | pattern: pattern, view: View.new(snapshot), last_tick: nil})
  end

  defp advance(game) do
    started = System.monotonic_time(:microsecond)
    %Snapshot{} = snapshot = Board.tick()
    now = System.monotonic_time(:microsecond)

    rate =
      case game.last_tick do
        nil -> game.rate
        last_tick -> smooth(game.rate, 1_000_000 / max(now - last_tick, 1))
      end

    %{
      game
      | view: View.advance(game.view, snapshot),
        tick_ms: smooth(game.tick_ms, (now - started) / 1000),
        rate: rate,
        last_tick: now
    }
  end

  defp draw(game) do
    {width, height} = game.view.size
    screen = Terminal.size(game.device, {width, div(height + 1, 2) + 1})
    clear = if screen == game.screen, do: [], else: Terminal.clear()

    hud = %{
      status: game.status,
      pattern: if(is_atom(game.pattern), do: Patterns.label(game.pattern), else: "Custom"),
      rate: game.rate,
      tick_ms: game.tick_ms,
      interactive: game.interactive,
      help: game.help
    }

    IO.write(game.device, [clear, Renderer.frame(game.view, game.palette, hud, screen)])
    %{game | screen: screen}
  end

  defp schedule(%{status: :running} = game, delay) do
    timer = make_ref()
    Process.send_after(self(), {:tick, timer}, delay)
    %{game | timer: timer}
  end

  defp schedule(game, _delay), do: game

  defp smooth(average, value) when average == 0.0, do: value
  defp smooth(average, value), do: average * 0.8 + value * 0.2

  defp next(list, current) do
    case Enum.find_index(list, &(&1 == current)) do
      nil -> hd(list)
      index -> Enum.at(list, rem(index + 1, length(list)))
    end
  end
end
