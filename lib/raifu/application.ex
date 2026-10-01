defmodule Raifu.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Raifu.CellRegistry, partitions: System.schedulers_online()},
      Raifu.CellSupervisor,
      Raifu.Board,
      Raifu.Runner
    ]

    # Each child depends on the ones started before it: if the cells go down,
    # the board and the runner must restart too, but not the other way around.
    Supervisor.start_link(children, strategy: :rest_for_one, name: Raifu.Supervisor)
  end
end
