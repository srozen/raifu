defmodule Raifu do
  @moduledoc """
  Conway's Game of Life where every cell of the board is its own process.

    * `Raifu.Cell` - a cell, which tells its neighbours whether it is alive and
      computes its next state once it has heard from all of them
    * `Raifu.CellSupervisor` - supervises the cells
    * `Raifu.Board` - orchestrates the cells, one generation at a time
    * `Raifu.Runner` - ticks the board at a steady pace and draws it
    * `Raifu.TUI` - the full screen, interactive game run by `mix life`
  """
end
