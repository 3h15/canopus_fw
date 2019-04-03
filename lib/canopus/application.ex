defmodule Canopus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # supervisor(Phoenix.PubSub.PG2, [Nerves.PubSub, [poolsize: 1]]),
      {Canopus.I2c, :ok}, # No dependencies

      {Canopus.Thermostat, :ok}, # Depends on I2c
      {Canopus.Heater, :ok}, # Depends on I2c, Thermostat, and I2c through Clock
      {Canopus.Serial, :ok}, # Depends on thermostat, to update sensors
    ]

    opts = [strategy: :one_for_one, name: Canopus.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
