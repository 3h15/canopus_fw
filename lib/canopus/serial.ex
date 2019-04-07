defmodule Canopus.Serial do

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do

    {:ok, pid} = Circuits.UART.start_link
    Circuits.UART.open(pid, "ttyAMA0",
      speed: 9600,
      active: true,
      framing: {Circuits.UART.Framing.Line, separator: "\r\n"},
      rx_framing_timeout: 500
    )

    Logger.info("SERIAL: Port open.");
    {:ok, []}
  end

  # The bluetooth receiver sends "START" at begining.
  def handle_info({:circuits_uart, "ttyAMA0", "START"}, state) do
    Logger.info("SERIAL: communication established.")
    {:noreply, state}
  end

  # The receiver send data for each sensor temp received.
  def handle_info({:circuits_uart, "ttyAMA0", data}, state) when is_binary(data) do
    Logger.info("SERIAL: Received: #{data}")
    [sensor_id, temperature, _humidity, validity] = String.split(data, "|")
    if validity == "1" do
      GenServer.call Canopus.Thermostat, {:update_sensor, sensor_id, temperature}
    else
      Logger.info("SERIAL: Ignored corrupted data.")
    end
    {:noreply, state}
  end

  # IF something goes wrong, we could receive {:partial, data} messages.
  # Logging these ensures I won't be debugging for days in a couple of years.
  def handle_info({:circuits_uart, "ttyAMA0", {token, data}}, state) when is_binary(data) do
    Logger.info("SERIAL: Received #{token}")
    Logger.info("SERIAL: Received #{data}")
    {:noreply, state}
  end

end
