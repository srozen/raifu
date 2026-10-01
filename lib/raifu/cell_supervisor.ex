defmodule Raifu.CellSupervisor do
  @moduledoc """
  Dynamic supervisor owning every cell process of the board.
  """

  use DynamicSupervisor

  alias Raifu.{Cell, Grid}

  ## Public API

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Starts one cell per position of the board, alive when listed in `alive`."
  @spec start_cells(Grid.size(), Grid.topology(), MapSet.t(Grid.position())) :: :ok
  def start_cells(size, topology, alive) do
    for position <- Grid.positions(size) do
      opts = [
        position: position,
        neighbors: Grid.neighbors(position, size, topology),
        alive?: MapSet.member?(alive, position)
      ]

      {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, {Cell, opts})
    end

    :ok
  end

  @doc "Terminates every cell."
  @spec stop_cells() :: :ok
  def stop_cells do
    for {_id, pid, _type, _modules} <- DynamicSupervisor.which_children(__MODULE__) do
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end

    :ok
  end

  @doc "The number of running cells."
  @spec count_cells() :: non_neg_integer()
  def count_cells, do: DynamicSupervisor.count_children(__MODULE__).active

  ## Implementation

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
