defmodule Raifu.Board do
  use GenServer
  require Logger

  ## Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Implementation
  @impl true
  def init(opts) do
    Logger.debug("Board started.")
    {:ok, opts}
  end
end
