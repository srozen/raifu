defmodule Raifu.Cell do
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
