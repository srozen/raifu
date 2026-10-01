defmodule Raifu.View do
  @moduledoc """
  What the runner remembers between two generations in order to draw them:
  for how long each cell has been alive, the fading trail of the cells that
  died recently, and a few statistics about the population.
  """

  alias Raifu.{Grid, Snapshot}

  # Generations during which a dead cell stays visible.
  @trail 8
  # Populations kept for the sparkline.
  @history 32
  # Generations searched for a repeating board.
  @period_window 30

  @enforce_keys [:size, :topology]
  defstruct [
    :size,
    :topology,
    generation: 0,
    ages: %{},
    ghosts: %{},
    population: 0,
    births: 0,
    deaths: 0,
    period: nil,
    history: [],
    hashes: []
  ]

  @type t :: %__MODULE__{
          size: Grid.size(),
          topology: Grid.topology(),
          generation: non_neg_integer(),
          ages: %{Grid.position() => pos_integer()},
          ghosts: %{Grid.position() => pos_integer()},
          population: non_neg_integer(),
          births: non_neg_integer(),
          deaths: non_neg_integer(),
          period: pos_integer() | nil,
          history: [non_neg_integer()],
          hashes: [integer()]
        }

  @doc "How many generations a dead cell stays visible."
  @spec trail() :: pos_integer()
  def trail, do: @trail

  @doc "Starts a view from a first snapshot."
  @spec new(Snapshot.t()) :: t()
  def new(%Snapshot{} = snapshot) do
    population = MapSet.size(snapshot.alive)

    %__MODULE__{
      size: snapshot.size,
      topology: snapshot.topology,
      generation: snapshot.generation,
      ages: Map.from_keys(MapSet.to_list(snapshot.alive), 1),
      population: population,
      history: [population],
      hashes: [:erlang.phash2(snapshot.alive)]
    }
  end

  @doc "Moves the view on to the next snapshot."
  @spec advance(t(), Snapshot.t()) :: t()
  def advance(%__MODULE__{} = view, %Snapshot{alive: alive} = snapshot) do
    ages = Map.new(alive, fn position -> {position, Map.get(view.ages, position, 0) + 1} end)
    died = for {position, _age} <- view.ages, not MapSet.member?(alive, position), do: position

    ghosts =
      for {position, fade} <- view.ghosts,
          fade < @trail,
          not MapSet.member?(alive, position),
          into: Map.from_keys(died, 1),
          do: {position, fade + 1}

    population = MapSet.size(alive)
    hash = :erlang.phash2(alive)

    period =
      case Enum.find_index(view.hashes, &(&1 == hash)) do
        nil -> nil
        index -> index + 1
      end

    %{
      view
      | generation: snapshot.generation,
        ages: ages,
        ghosts: ghosts,
        population: population,
        births: population - (map_size(view.ages) - length(died)),
        deaths: length(died),
        period: period,
        history: Enum.take([population | view.history], @history),
        hashes: Enum.take([hash | view.hashes], @period_window)
    }
  end

  @doc """
  What the board has settled into, if anything: `:extinct`, `:still` (still
  life), `{:oscillating, period}`, or `nil` while it keeps evolving.
  """
  @spec outcome(t()) :: :extinct | :still | {:oscillating, pos_integer()} | nil
  def outcome(%__MODULE__{population: 0}), do: :extinct
  def outcome(%__MODULE__{period: 1}), do: :still
  def outcome(%__MODULE__{period: nil}), do: nil
  def outcome(%__MODULE__{period: period}), do: {:oscillating, period}
end
