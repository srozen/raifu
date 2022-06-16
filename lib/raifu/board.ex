defmodule Raifu.Board do
  use GenServer

  ## Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Implementation
  @impl true
  def init(opts) do
    {:ok, opts}
  end
end
