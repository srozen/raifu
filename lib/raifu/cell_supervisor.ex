defmodule Raifu.CellSupervisor do
  use DynamicSupervisor
  alias Raifu.Cell

  ## Public API
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def setup_cells({width, length} = _opts) do
    for x <- 0..width, y <- 0..length do
      cell_name = Cell.cell_name({x,y})
      spec = %{
        id: cell_name,
        start: {Cell, :start_link, [{{x, y}, width, length}]}
      }
      DynamicSupervisor.start_child(__MODULE__, spec)
      cell_name
    end
  end

  def destroy_cells() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end)
  end

  def count_cells() do
    DynamicSupervisor.count_children(__MODULE__)
  end

  ## Implementation
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
