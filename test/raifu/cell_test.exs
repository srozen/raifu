defmodule Raifu.CellTest do
  use ExUnit.Case, async: false

  alias Raifu.Cell

  doctest Cell

  describe "next_state/2" do
    test "a live cell survives with two or three live neighbours" do
      for alive_neighbors <- 0..8 do
        assert Cell.next_state(true, alive_neighbors) == alive_neighbors in [2, 3]
      end
    end

    test "a dead cell comes to life with exactly three live neighbours" do
      for alive_neighbors <- 0..8 do
        assert Cell.next_state(false, alive_neighbors) == (alive_neighbors == 3)
      end
    end
  end

  describe "tick/3" do
    setup do
      start_supervised!({Registry, keys: :unique, name: Raifu.CellRegistry})

      # The test process stands in for both neighbours of the cell.
      {:ok, _owner} = Registry.register(Raifu.CellRegistry, {0, 1}, nil)
      {:ok, _owner} = Registry.register(Raifu.CellRegistry, {1, 1}, nil)
      start_supervised!({Cell, position: {0, 0}, neighbors: [{0, 1}, {1, 1}], alive?: true})

      :ok
    end

    test "tells the neighbours, then reports once it has heard from all of them" do
      :ok = Cell.tick({0, 0}, 0, self())

      assert_receive {:"$gen_cast", {:neighbor, 0, true}}
      assert_receive {:"$gen_cast", {:neighbor, 0, true}}

      tell({0, 0}, 0, true)
      refute_receive {:cell_state, _generation, _position, _alive?}, 50

      tell({0, 0}, 0, true)
      assert_receive {:cell_state, 1, {0, 0}, true}
      assert Cell.alive?({0, 0})
    end

    test "accepts news from its neighbours before its own tick" do
      tell({0, 0}, 0, true)
      tell({0, 0}, 0, false)
      refute_receive {:cell_state, _generation, _position, _alive?}, 50

      :ok = Cell.tick({0, 0}, 0, self())
      assert_receive {:cell_state, 1, {0, 0}, false}
      refute Cell.alive?({0, 0})
    end

    test "reset/2 brings the cell back to generation 0" do
      :ok = Cell.tick({0, 0}, 0, self())
      tell({0, 0}, 0, false)
      tell({0, 0}, 0, false)
      assert_receive {:cell_state, 1, {0, 0}, false}

      :ok = Cell.reset({0, 0}, true)
      :ok = Cell.tick({0, 0}, 0, self())
      assert_receive {:"$gen_cast", {:neighbor, 0, true}}
    end
  end

  defp tell(position, generation, alive?) do
    GenServer.cast(Cell.via(position), {:neighbor, generation, alive?})
  end
end
