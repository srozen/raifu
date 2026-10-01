defmodule Raifu.RunnerTest do
  use ExUnit.Case, async: false

  alias Raifu.{Board, CellSupervisor, Runner, Screen, Snapshot}

  setup do
    start_supervised!({Registry, keys: :unique, name: Raifu.CellRegistry})
    start_supervised!(CellSupervisor)
    start_supervised!(Board)
    start_supervised!(Runner)

    {:ok, device} = StringIO.open("")
    %{device: device}
  end

  test "draws the board, then one more generation at each step", %{device: device} do
    :ok = start_game(device, pattern: :r_pentomino)
    assert status_bar(device) =~ "gen 0"

    Runner.command(:step)
    assert status_bar(device) =~ "gen 1"
    assert %Snapshot{generation: 1} = Board.snapshot()
  end

  test "plays on its own once resumed", %{device: device} do
    :ok = start_game(device, delay: 0)
    Runner.command(:resume)

    assert eventually(fn -> Board.snapshot().generation >= 5 end)
  end

  test "switching patterns re-seeds the board", %{device: device} do
    :ok = start_game(device, pattern: :acorn)
    assert status_bar(device) =~ "Acorn"

    Runner.command(:next_pattern)
    assert status_bar(device) =~ "R-pentomino"
    assert %Snapshot{generation: 0, alive: alive} = Board.snapshot()
    assert MapSet.size(alive) == 5
  end

  test "a board must be at least 2×2" do
    assert Runner.start_game(1, 10) == {:error, :board_too_small}
  end

  test "unknown patterns and themes are rejected" do
    assert_raise ArgumentError, ~r/unknown pattern/, fn ->
      Runner.start_game(5, 5, pattern: :nope)
    end

    assert_raise ArgumentError, ~r/unknown theme/, fn -> Runner.start_game(5, 5, theme: :nope) end
  end

  test "commands are ignored once the game is stopped", %{device: device} do
    :ok = start_game(device, [])
    :ok = Runner.stop_game()
    StringIO.flush(device)

    Runner.command(:step)
    _state = :sys.get_state(Runner)

    assert StringIO.flush(device) == ""
    assert %Snapshot{generation: 0} = Board.snapshot()
  end

  # Without a terminal, the runner draws on a screen as wide as the board:
  # 120 columns, and 6 lines of which the last is the status bar.
  defp start_game(device, opts) do
    Runner.start_game(120, 10, [device: device, paused: true, depth: :truecolor] ++ opts)
  end

  defp status_bar(device) do
    # Waits for the runner to handle the commands sent so far.
    _state = :sys.get_state(Runner)
    device |> StringIO.flush() |> Screen.play() |> Screen.text(6, 1, 120)
  end

  defp eventually(check, attempts \\ 100) do
    cond do
      check.() -> true
      attempts == 0 -> false
      true -> Process.sleep(10) && eventually(check, attempts - 1)
    end
  end
end
