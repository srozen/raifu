defmodule Raifu.Board do
  @moduledoc """
  Orchestrates the cells of the board.

  `tick/0` wakes every cell up and then collects their new states as they
  report back. The board does not block while the cells work: `handle_call/3`
  returns `:noreply` and the caller only gets its answer, through
  `GenServer.reply/2`, once the whole generation has been computed.
  """

  use GenServer

  alias Raifu.{Cell, CellSupervisor, Grid, Patterns, Snapshot}

  @setup_timeout :timer.seconds(30)
  @tick_timeout :timer.seconds(30)

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  (Re)creates a board of `width × height` cells.

  ## Options

    * `:topology` - `:bounded` (default) or `:torus`
    * `:pattern` - how to seed the board, see `Raifu.Patterns.seed/3`.
      Defaults to `:random`
    * `:density` - the density of a `:random` seed

  """
  @spec setup(pos_integer(), pos_integer(), keyword()) :: :ok | {:error, :busy}
  def setup(width, height, opts \\ [])
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    Patterns.validate!(Keyword.get(opts, :pattern, :random))
    GenServer.call(__MODULE__, {:setup, {width, height}, opts}, @setup_timeout)
  end

  @doc """
  Re-seeds the current board and brings it back to generation 0, reusing its
  cells. Takes the same options as `setup/3`, except for `:topology`.
  """
  @spec seed(Patterns.seed(), keyword()) :: :ok | {:error, :busy | :no_board}
  def seed(pattern, opts \\ []) do
    Patterns.validate!(pattern)
    GenServer.call(__MODULE__, {:seed, pattern, opts}, @setup_timeout)
  end

  @doc "Advances the board by one generation."
  @spec tick() :: Snapshot.t() | {:error, :busy | :no_board}
  def tick do
    # The board always answers or crashes within @tick_timeout, and a crash
    # exits the caller as well: no need for a client-side timeout.
    GenServer.call(__MODULE__, :tick, :infinity)
  end

  @doc "The current state of the board."
  @spec snapshot() :: Snapshot.t() | {:error, :no_board}
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  ## Implementation

  @impl GenServer
  def init(_opts) do
    {:ok, %{size: nil, topology: nil, positions: [], generation: 0, alive: nil, pending: nil}}
  end

  @impl GenServer
  def handle_call(:snapshot, _from, %{size: nil} = state),
    do: {:reply, {:error, :no_board}, state}

  def handle_call(:snapshot, _from, state), do: {:reply, snapshot(state), state}

  def handle_call(_request, _from, %{pending: %{}} = state), do: {:reply, {:error, :busy}, state}

  def handle_call({:setup, size, opts}, _from, state) do
    topology = Keyword.get(opts, :topology, :bounded)
    alive = Patterns.seed(Keyword.get(opts, :pattern, :random), size, opts)

    :ok = CellSupervisor.stop_cells()
    :ok = CellSupervisor.start_cells(size, topology, alive)

    state = %{
      state
      | size: size,
        topology: topology,
        positions: Grid.positions(size),
        generation: 0,
        alive: alive
    }

    {:reply, :ok, state}
  end

  def handle_call(_request, _from, %{size: nil} = state), do: {:reply, {:error, :no_board}, state}

  def handle_call({:seed, pattern, opts}, _from, state) do
    alive = Patterns.seed(pattern, state.size, opts)

    for position <- state.positions do
      Cell.reset(position, MapSet.member?(alive, position))
    end

    {:reply, :ok, %{state | generation: 0, alive: alive}}
  end

  def handle_call(:tick, from, %{size: {width, height}} = state) do
    for position <- state.positions do
      Cell.tick(position, state.generation, self())
    end

    pending = %{
      from: from,
      alive: MapSet.new(),
      remaining: width * height,
      timer: :erlang.start_timer(@tick_timeout, self(), :tick_timeout)
    }

    {:noreply, %{state | pending: pending}}
  end

  @impl GenServer
  def handle_info(
        {:cell_state, generation, position, alive?},
        %{generation: current, pending: %{} = pending} = state
      )
      when generation == current + 1 do
    alive = if alive?, do: MapSet.put(pending.alive, position), else: pending.alive

    case pending.remaining - 1 do
      0 ->
        Process.cancel_timer(pending.timer)
        state = %{state | generation: generation, alive: alive, pending: nil}
        GenServer.reply(pending.from, snapshot(state))
        {:noreply, state}

      remaining ->
        {:noreply, %{state | pending: %{pending | alive: alive, remaining: remaining}}}
    end
  end

  # Some cell never answered: crash, so our supervisor restarts us and the
  # runner in a clean state.
  def handle_info({:timeout, timer, :tick_timeout}, %{pending: %{timer: timer}} = state) do
    {:stop, :tick_timeout, state}
  end

  def handle_info({:timeout, _stale_timer, :tick_timeout}, state), do: {:noreply, state}

  defp snapshot(state) do
    %Snapshot{
      generation: state.generation,
      size: state.size,
      topology: state.topology,
      alive: state.alive
    }
  end
end
