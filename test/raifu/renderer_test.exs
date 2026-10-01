defmodule Raifu.RendererTest do
  use ExUnit.Case, async: true

  alias Raifu.{Renderer, Screen, Snapshot, Theme, View}

  @hud %{
    status: :running,
    pattern: "Acorn",
    rate: 9.5,
    tick_ms: 1.2,
    interactive: false,
    help: false
  }

  setup do
    %{palette: Theme.palette(:ember, :truecolor, View.trail())}
  end

  test "each line of the terminal shows two rows of the board", %{palette: palette} do
    screen =
      [{0, 0}, {1, 1}] |> view({4, 4}) |> Renderer.frame(palette, @hud, {4, 3}) |> Screen.play()

    newborn = Theme.life(palette, 1)
    background = palette.background

    assert {"▀", ^newborn, ^background} = screen[{1, 1}]
    assert {"▀", ^background, ^newborn} = screen[{1, 2}]
    assert {" ", _fg, ^background} = screen[{1, 3}]
    assert Screen.text(screen, 2, 1, 4) == "    "
  end

  test "cells are colored after their age, ghosts after their fade", %{palette: palette} do
    view =
      [{0, 0}, {0, 1}]
      |> view({1, 2})
      |> View.advance(%Snapshot{
        generation: 1,
        size: {1, 2},
        topology: :bounded,
        alive: MapSet.new([{0, 0}])
      })

    screen = view |> Renderer.frame(palette, @hud, {1, 2}) |> Screen.play()
    {old, ghost} = {Theme.life(palette, 2), Theme.trail(palette, 1)}

    assert {"▀", ^old, ^ghost} = screen[{1, 1}]
  end

  test "a board smaller than the terminal is centered in the void", %{palette: palette} do
    screen = [] |> view({2, 2}) |> Renderer.frame(palette, @hud, {6, 2}) |> Screen.play()
    {void, background} = {palette.void, palette.background}

    assert {" ", _fg, ^void} = screen[{1, 2}]
    assert {" ", _fg, ^background} = screen[{1, 3}]
    assert {" ", _fg, ^background} = screen[{1, 4}]
    assert {" ", _fg, ^void} = screen[{1, 5}]
  end

  test "the status bar sums the game up", %{palette: palette} do
    status = [{0, 0}, {1, 0}] |> view({20, 20}) |> status_bar(palette, @hud, 150)

    assert status =~ "RAIFU"
    assert status =~ "gen 0"
    assert status =~ "pop 2"
    assert status =~ "Acorn"
    assert status =~ "torus 20×20"
    assert status =~ "9.5 gen/s"
    refute status =~ "quit"
  end

  test "the status bar drops details to fit the terminal", %{palette: palette} do
    screen = [] |> view({20, 20}) |> Renderer.frame(palette, @hud, {40, 11}) |> Screen.play()
    columns = for {{11, column}, _cell} <- screen, do: column

    assert Enum.max(columns) <= 39
    assert Screen.text(screen, 11, 1, 39) =~ "gen 0"
  end

  test "interactive games show their controls", %{palette: palette} do
    view = view([], {20, 20})

    running = status_bar(view, palette, %{@hud | interactive: true}, 200)
    assert running =~ "space pause"
    assert running =~ "q quit"

    paused = status_bar(view, palette, %{@hud | interactive: true, status: :paused}, 200)
    assert paused =~ "space play"
    assert paused =~ "paused"
  end

  test "narrow terminals only hint at the help", %{palette: palette} do
    status = [] |> view({20, 20}) |> status_bar(palette, %{@hud | interactive: true}, 80)

    assert status =~ "gen 0"
    assert status =~ "Acorn"
    assert status =~ "? help"
    refute status =~ "quit"
  end

  test "the help lists the controls over the board", %{palette: palette} do
    screen =
      []
      |> view({60, 40})
      |> Renderer.frame(palette, %{@hud | interactive: true, help: true}, {60, 21})
      |> Screen.play()

    help = Enum.map_join(1..20, "\n", &Screen.text(screen, &1, 1, 60))

    assert help =~ "╭─"
    assert help =~ "controls"
    assert help =~ ~r/space\s+pause \/ play/
    assert help =~ ~r/q\s+quit/
  end

  defp view(alive, size) do
    View.new(%Snapshot{generation: 0, size: size, topology: :torus, alive: MapSet.new(alive)})
  end

  defp status_bar(view, palette, hud, columns) do
    view
    |> Renderer.frame(palette, hud, {columns, 12})
    |> Screen.play()
    |> Screen.text(12, 1, columns)
  end
end
