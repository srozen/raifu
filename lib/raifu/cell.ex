defmodule Raifu.Cell do
  use GenServer, restart: :transient
  require Logger
  ## Public API
  def start_link({position, _width, _length} = opts) do
    GenServer.start_link(__MODULE__, opts, name: cell_name(position))
  end

  def alive?(name) do
    GenServer.call(name, :alive)
  end

  def compute_next_state(name) do
    GenServer.call(name, :compute_next_state)
  end

  def toggle_next_state(name) do
    GenServer.call(name, :toggle_next_state)
  end

  # Implementation
  @impl true
  def init({position, width, length}) do
    neighbors = compute_neighborhood(position, width, length)
    alive = Enum.random([1,2]) == 2
    {:ok, {alive, alive, neighbors}}
  end

  @impl true
  def handle_call(:alive, _from, {alive, _, _} = state) do
    {:reply, alive, state}
  end

  @impl true
  def handle_call(:compute_next_state, _from, {alive, _, neighbors}) do
    number_neighbors_alive = neighbors
      |> Enum.map(fn neighbor -> alive?(neighbor) end)
      |> Enum.count(fn alive -> alive end)

    next_state = compute_next_state(alive, number_neighbors_alive)

    {:reply, next_state, {alive, next_state, neighbors}}
  end

  @impl true
  def handle_call(:toggle_next_state, _from, {_alive, next_state, neighbors}) do
    {:reply, next_state, {next_state, next_state, neighbors}}
  end

  def cell_name(position) do
    pos = position |> Tuple.to_list() |> Enum.join()
    "cell#{pos}" |> String.to_atom()
  end

  def compute_next_state(alive, number_neighbors_alive) do
    case number_neighbors_alive do
      n when alive and n < 2 -> false
      n when alive and n > 3 -> false
      2 when alive -> true
      3 when alive -> true
      3 when not alive -> true
      _ -> false
    end
  end

  def compute_neighborhood({x,y}, width, length) do
    for m <- x-1..x+1, n <- y-1..y+1 do
      {m,n}
    end
    |> Enum.filter(&filter_invalid_positions(&1, {x,y}, width, length))
    |> Enum.map(&(cell_name(&1)))
  end

  defp filter_invalid_positions(position, cell_position, width, length) do
    case position do
      position when position == cell_position -> false
      {x, y} when x < 0 or y < 0 -> false
      {x, y} when x > width or y > length -> false
      _ -> true
    end
  end
end
