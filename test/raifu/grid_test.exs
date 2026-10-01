defmodule Raifu.GridTest do
  use ExUnit.Case, async: true

  alias Raifu.Grid

  doctest Grid

  describe "positions/1" do
    test "lists every position of the board once" do
      positions = Grid.positions({12, 11})

      assert length(positions) == 132
      assert positions |> Enum.uniq() |> length() == 132
      assert {11, 10} in positions
    end
  end

  describe "neighbors/3 on a bounded board" do
    test "corner cells have three neighbours" do
      assert Enum.sort(Grid.neighbors({0, 0}, {3, 3}, :bounded)) == [{0, 1}, {1, 0}, {1, 1}]
      assert Enum.sort(Grid.neighbors({2, 2}, {3, 3}, :bounded)) == [{1, 1}, {1, 2}, {2, 1}]
    end

    test "edge cells have five neighbours" do
      assert Enum.sort(Grid.neighbors({1, 0}, {3, 3}, :bounded)) ==
               [{0, 0}, {0, 1}, {1, 1}, {2, 0}, {2, 1}]
    end

    test "inner cells have eight neighbours" do
      assert Enum.sort(Grid.neighbors({1, 1}, {3, 3}, :bounded)) ==
               [{0, 0}, {0, 1}, {0, 2}, {1, 0}, {1, 2}, {2, 0}, {2, 1}, {2, 2}]
    end

    test "tells apart positions whose digits look alike" do
      refute {11, 1} in Grid.neighbors({1, 11}, {12, 12}, :bounded)
    end
  end

  describe "neighbors/3 on a torus" do
    test "every cell has eight neighbours, wrapping around the edges" do
      assert Enum.sort(Grid.neighbors({0, 0}, {4, 4}, :torus)) ==
               [{0, 1}, {0, 3}, {1, 0}, {1, 1}, {1, 3}, {3, 0}, {3, 1}, {3, 3}]
    end

    test "on a tiny torus, a neighbour counts as many times as it touches the cell" do
      neighbors = Grid.neighbors({0, 0}, {2, 3}, :torus)

      assert length(neighbors) == 8
      assert Enum.count(neighbors, &(&1 == {1, 0})) == 2
      assert Enum.count(neighbors, &(&1 == {0, 1})) == 1
    end
  end
end
