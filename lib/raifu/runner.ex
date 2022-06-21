defmodule Raifu.Runner do
  use GenServer
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  def print_board(_board, _length) do
    clear_screen()
  end

  def clear_screen() do
    IO.write [IO.ANSI.clear, IO.ANSI.home]
    IO.write [?\r, ?\n]
  end
end
