defmodule Raifu.Cell do
  @behaviour GenServer
  # Public API
  def start_link({position, _width, _length} = opts) do
    GenServer.start_link(__MODULE__, opts, name: cell_name(position))
  end

  def alive?(name) do
    GenServer.call(name, :alive)
  end

  def cell_name(position) do
    pos = position |> Tuple.to_list() |> Enum.join()
    "cell#{pos}" |> String.to_atom()
  end

  # GenServer Callbacks
  @impl true
  def init({position, width, length}) do
    neighbors = compute_neighborhood(position, width, length)
    alive = Enum.random([1,2]) == 2
    {:ok, {alive, neighbors}}
  end

  @impl true
  def handle_call(:alive, _from, {alive, neighbors}) do
    {:reply, alive, {alive, neighbors}}
  end

  def compute_neighborhood({x,y}, width, length) do
    for m <- x-1..x+1, n <- y-1..y+1 do
      {m,n}
    end
    |> Enum.filter(&filter_invalid_positions(&1, {x,y}, width, length))
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
