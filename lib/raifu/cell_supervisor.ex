defmodule Raifu.CellSupervisor do
  use Supervisor
  alias Raifu.Cell

  ## Public API
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Implementation
  @impl true
  def init({width, length} = _opts) do
    children = for x <- 0..width, y <- 0..length do
      cell_name = Cell.cell_name({x,y})
      %{
        id: cell_name,
        start: {Cell, :start_link, [{{x, y}, width, length}]}
      }
    end
    Supervisor.init(children, strategy: :one_for_all)
  end
end
