defmodule Raifu.ViewTest do
  use ExUnit.Case, async: true

  alias Raifu.{Snapshot, View}

  test "tracks for how long cells have been alive" do
    view =
      View.new(snapshot(0, [{0, 0}, {1, 0}]))
      |> View.advance(snapshot(1, [{0, 0}, {2, 0}]))
      |> View.advance(snapshot(2, [{0, 0}, {2, 0}]))

    assert view.ages == %{{0, 0} => 3, {2, 0} => 2}
  end

  test "dead cells leave a fading trail" do
    view =
      View.new(snapshot(0, [{0, 0}]))
      |> View.advance(snapshot(1, []))
      |> View.advance(snapshot(2, []))

    assert view.ghosts == %{{0, 0} => 2}

    view = Enum.reduce(3..(View.trail() + 1), view, &View.advance(&2, snapshot(&1, [])))
    assert view.ghosts == %{}
  end

  test "a cell coming back to life is no longer a ghost" do
    view =
      View.new(snapshot(0, [{0, 0}]))
      |> View.advance(snapshot(1, []))
      |> View.advance(snapshot(2, [{0, 0}]))

    assert view.ghosts == %{}
    assert view.ages == %{{0, 0} => 1}
  end

  test "counts births and deaths" do
    view =
      View.new(snapshot(0, [{0, 0}, {1, 0}, {2, 0}]))
      |> View.advance(snapshot(1, [{1, 0}, {1, 1}, {1, 2}, {3, 3}]))

    assert {view.population, view.births, view.deaths} == {4, 3, 2}
    assert view.history == [4, 3]
  end

  test "detects what the board settles into" do
    blinker = [{1, 0}, {1, 1}, {1, 2}]
    flipped = [{0, 1}, {1, 1}, {2, 1}]

    view = View.new(snapshot(0, blinker))
    assert View.outcome(view) == nil

    view = View.advance(view, snapshot(1, flipped))
    assert View.outcome(view) == nil

    view = View.advance(view, snapshot(2, blinker))
    assert View.outcome(view) == {:oscillating, 2}

    assert View.outcome(View.advance(view, snapshot(3, blinker))) == :still
    assert View.outcome(View.advance(view, snapshot(3, []))) == :extinct
  end

  defp snapshot(generation, alive) do
    %Snapshot{generation: generation, size: {4, 4}, topology: :bounded, alive: MapSet.new(alive)}
  end
end
