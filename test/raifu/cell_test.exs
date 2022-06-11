defmodule RaifuTest.Cell do
  use ExUnit.Case
  alias Raifu.Cell

  describe "alive/1" do
    test "returns the livingness status of the cell" do
      position = {1,1}
      name = Cell.cell_name(position)
      start_supervised!(%{id: Cell, start: {Cell, :start_link, [{position, 2, 2}]}})

      assert Cell.alive?(name) in [true, false]
    end
  end

  describe "compute neighborhood/3" do
    test "determine the proper set of neighbors for corner cells" do
      assert lists_are_equals?(Cell.compute_neighborhood({0,0}, 2, 2), [{0,1},{1,0}, {1,1}])

      assert lists_are_equals?(Cell.compute_neighborhood({2,2}, 2, 2), [{2,1},{1,2}, {1,1}])
    end

    test "determine the proper set of neighbors" do
      assert lists_are_equals?(Cell.compute_neighborhood({1,1}, 2, 2), [{0,0}, {0,1}, {0,2}, {1,0}, {1,2}, {2,0},{2,1}, {2,2} ])
    end
  end

  defp lists_are_equals?(list1, list2) do
    Enum.sort(list1) == Enum.sort(list2)
  end
end
