defmodule Raifu.Runner do
  use GenServer
  alias Raifu.Board
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_game(width, length) when width < 2 or length < 2 do
    IO.puts("Please use at least a 2*2 grid.")
  end

  def start_game(width, length) do
    GenServer.cast(__MODULE__, {:start, {width, length}})
  end

  def stop_game() do
    GenServer.cast(__MODULE__, :stop)
  end

  @impl true
  def init(_opts) do
    {:ok, %{running: false}}
  end

  @impl true
  def handle_cast({:start, _opts}, %{running: true} = state), do: {:noreply, state}
  def handle_cast({:start, {width, length}}, %{running: false} = _state) do
    Board.setup(width-1, length-1)
    schedule_tick()
    {:noreply, %{running: true, width: width, length: length}}
  end

  @impl true
  def handle_cast(:stop, _state), do: {:noreply, %{running: false}}

  @impl true
  def handle_info(:tick, %{running: false} = state), do: {:noreply, state}
  def handle_info(:tick, %{running: true, length: length} = state) do
    Board.tick()
    |> IO.inspect()
    |> print_board(length)

    schedule_tick()
    {:noreply, state}
  end


  def print_board(board, length) do
    clear_screen()
    board
    |> Enum.chunk_every(length)
    |> Enum.each(fn row -> print_row(row) end)
  end

  def print_row(cell_states) do
    cell_states
    |> Enum.each(fn state ->
      if state do
        IO.write("*")
      else
        IO.write("-")
      end
    end)
    IO.write([?\r, ?\n])
  end

  def clear_screen() do
    IO.write([IO.ANSI.clear, IO.ANSI.home])
    IO.write([?\r, ?\n])
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, :timer.seconds(2))
  end
end
