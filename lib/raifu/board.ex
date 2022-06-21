defmodule Raifu.Board do
  use GenServer
  require Logger
  alias Raifu.{Cell, CellSupervisor}

  ## Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def setup(width, length) do
    GenServer.call(__MODULE__, {:setup, {width, length}})
  end

  def tick() do
    GenServer.call(__MODULE__, :tick)
  end

  ## Implementation
  @impl true
  def init(_opts) do
    {:ok, {false, nil, nil}}
  end

  @impl true
  def handle_call({:setup, {width, length}}, _from, _state) do
    CellSupervisor.destroy_cells()
    cell_names = CellSupervisor.setup_cells({width, length})
    cell_states = cell_names |> Enum.map(&(Cell.alive?(&1)))
    {:reply, :ok, {true, cell_names, cell_states}}
  end

  @impl true
  def handle_call(:tick, _from, {_running, cells, _} = state) do
    cells |> Enum.map(fn cell -> Cell.compute_next_state(cell) end)
    cell_states = cells |> Enum.map(fn cell -> Cell.toggle_next_state(cell) end)
    {:reply, cell_states, state}
  end
end
