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

  describe "compute_next_state/2" do
    test "returns the next state of the cell depending" do
      refute Cell.compute_next_state(true, 1)
      assert Cell.compute_next_state(true, 2)
      assert Cell.compute_next_state(true, 3)
      refute Cell.compute_next_state(true, 5)
      assert Cell.compute_next_state(false, 3)
      refute Cell.compute_next_state(true, 5)
    end
  end

  describe "compute neighborhood/3" do
    test "determine the proper set of neighbors for corner cells" do
      assert lists_are_equals?(Cell.compute_neighborhood({0,0}, 2, 2), [:cell01, :cell10, :cell11])

      assert lists_are_equals?(Cell.compute_neighborhood({2,2}, 2, 2), [:cell21, :cell12, :cell11])
    end

    test "determine the proper set of neighbors" do
      assert lists_are_equals?(Cell.compute_neighborhood({1,1}, 2, 2), [:cell00, :cell01, :cell02, :cell10, :cell12, :cell20,:cell21, :cell22])
    end
  end

  defp lists_are_equals?(list1, list2) do
    Enum.sort(list1) == Enum.sort(list2)
  end
end
