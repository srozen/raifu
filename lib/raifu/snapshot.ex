defmodule Raifu.Snapshot do
  @moduledoc """
  The state of the whole board at a given generation.
  """

  alias Raifu.Grid

  @enforce_keys [:generation, :size, :topology, :alive]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          generation: non_neg_integer(),
          size: Grid.size(),
          topology: Grid.topology(),
          alive: MapSet.t(Grid.position())
        }
end
