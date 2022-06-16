defmodule Raifu.CellSupervisor do
  use DynamicSupervisor
  alias Raifu.Cell

  ## Public API
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_game({width, length} = _opts) do
    for x <- 0..width, y <- 0..length do
      cell_name = Cell.cell_name({x,y})
      %{
        id: cell_name,
        start: {Cell, :start_link, [{{x, y}, width, length}]}
      }
    end
    |> Enum.each(&(DynamicSupervisor.start_child(__MODULE__, &1)))
  end

  def kill_all_childs() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end)
  end

  def how_many_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end

  ## Implementation
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
