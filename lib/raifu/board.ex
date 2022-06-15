defmodule Raifu.Board do
  use DynamicSupervisor

  ## Public API
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Implementation
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :all_for_one)
  end
end
