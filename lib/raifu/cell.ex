defmodule Raifu.Cell do
  @moduledoc """
  A single cell of the board, living in its own process.

  Cells never *ask* their neighbours anything, they *tell* them. On every tick:

    1. the board sends `{:tick, generation, reply_to}` to every cell;
    2. each cell sends its own state to each of its neighbours;
    3. once a cell has heard from all its neighbours, it applies the rules and
       sends `{:cell_state, generation + 1, position, alive?}` to `reply_to`.

  Since no cell ever waits on a reply from another one, the whole board
  advances concurrently without any risk of deadlock.

  Cells are registered in `Raifu.CellRegistry` under their position.
  """

  use GenServer, restart: :transient

  alias Raifu.Grid

  @registry Raifu.CellRegistry

  ## Public API

  @doc """
  Starts a cell.

  ## Options

    * `:position` (required) - the `{x, y}` position of the cell
    * `:neighbors` (required) - the positions of its neighbours
    * `:alive?` - whether the cell starts alive, defaults to `false`
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    position = Keyword.fetch!(opts, :position)
    GenServer.start_link(__MODULE__, opts, name: via(position))
  end

  @doc "The name of the cell at `position`."
  @spec via(Grid.position()) :: GenServer.name()
  def via(position), do: {:via, Registry, {@registry, position}}

  @doc "Whether the cell at `position` is currently alive."
  @spec alive?(Grid.position()) :: boolean()
  def alive?(position), do: GenServer.call(via(position), :alive?)

  @doc """
  Asks the cell at `position` to compute its next generation.

  `generation` must be the cell's current generation. The result is sent to
  `reply_to` as `{:cell_state, generation + 1, position, alive?}`.
  """
  @spec tick(Grid.position(), non_neg_integer(), pid()) :: :ok
  def tick(position, generation, reply_to) do
    GenServer.cast(via(position), {:tick, generation, reply_to})
  end

  @doc "Brings the cell back to generation 0 with the given state."
  @spec reset(Grid.position(), boolean()) :: :ok
  def reset(position, alive?), do: GenServer.cast(via(position), {:reset, alive?})

  @doc """
  Conway's rules: a live cell survives with 2 or 3 live neighbours, a dead
  cell comes to life with exactly 3.

      iex> Raifu.Cell.next_state(true, 2)
      true
      iex> Raifu.Cell.next_state(false, 2)
      false
  """
  @spec next_state(alive? :: boolean(), alive_neighbors :: non_neg_integer()) :: boolean()
  def next_state(true, alive_neighbors) when alive_neighbors in [2, 3], do: true
  def next_state(false, 3), do: true
  def next_state(_alive?, _alive_neighbors), do: false

  ## Implementation

  @impl GenServer
  def init(opts) do
    neighbors = Keyword.fetch!(opts, :neighbors)

    state = %{
      position: Keyword.fetch!(opts, :position),
      neighbors: neighbors,
      expected: length(neighbors),
      alive?: Keyword.get(opts, :alive?, false),
      generation: 0,
      heard: 0,
      alive_neighbors: 0,
      reply_to: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:alive?, _from, state), do: {:reply, state.alive?, state}

  # Messages for another generation than ours are a protocol violation:
  # they are left unmatched on purpose, so the cell crashes.
  @impl GenServer
  def handle_cast({:tick, generation, reply_to}, %{generation: generation} = state) do
    for neighbor <- state.neighbors do
      GenServer.cast(via(neighbor), {:neighbor, generation, state.alive?})
    end

    maybe_advance(%{state | reply_to: reply_to})
  end

  def handle_cast({:neighbor, generation, alive?}, %{generation: generation} = state) do
    alive_neighbors = if alive?, do: state.alive_neighbors + 1, else: state.alive_neighbors
    maybe_advance(%{state | heard: state.heard + 1, alive_neighbors: alive_neighbors})
  end

  def handle_cast({:reset, alive?}, state) do
    {:noreply, %{state | alive?: alive?, generation: 0} |> clear_round()}
  end

  # A neighbour's state can arrive before our own tick: we only move on once
  # we have both been ticked and heard from every neighbour.
  defp maybe_advance(%{reply_to: reply_to, heard: expected, expected: expected} = state)
       when is_pid(reply_to) do
    alive? = next_state(state.alive?, state.alive_neighbors)
    generation = state.generation + 1
    send(reply_to, {:cell_state, generation, state.position, alive?})

    {:noreply, %{state | alive?: alive?, generation: generation} |> clear_round()}
  end

  defp maybe_advance(state), do: {:noreply, state}

  defp clear_round(state), do: %{state | heard: 0, alive_neighbors: 0, reply_to: nil}
end
