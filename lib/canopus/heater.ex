defmodule Canopus.Heater do

  @persist "/root/heater.json"

  @heater_pin 16

  use GenServer
  require Logger


  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    # Heater structure
    state = %{
      is_on: "off",
    }

    # Update with data from disk
    state = read_data_from_disk(state)

    update_heater( state )

    {:ok, state}
  end

  def handle_call( :get_heater, _from, state ) do
    {:reply, state, state}
  end

  def handle_call( {:set_heater, on}, _from, state ) when on in ["on", "off"] do

    # Change state
    state = state |> Map.put(:is_on, on)

    # Persist state
    persist( state )

    update_heater( state )

    {:reply, :ok, state}
  end

  defp update_heater( state ) do
    pinState = case state.is_on do
      "on" -> :off # Heater in ON when pin is OFF
      "off" -> :on
    end
    GenServer.call(Canopus.I2c, %{pin: @heater_pin, to: pinState})
  end

  defp read_data_from_disk state do
    with {:ok, json} <- File.read(@persist),
         {:ok, persisted_state} <- Poison.decode(json) do
      Logger.info('HEATER: Loaded persisted state.')
      read_persisted_state(state, persisted_state)
    else
      _ -> Logger.info('HEATER: Unable to load persisted state.')
        state
    end
  end

  defp read_persisted_state state, persisted_state do
    # Reads persisted state and copy values to state
    # We copy values one by one, using state structure to get the values
    # This way, we avoid any json corruption to survive a reboot
    # and removed properties won't stay in file forever.
    state
    |> Enum.map( fn( {key, value} ) ->
      persisted_value = persisted_state[to_string(key)]
      {key, persisted_value || value}
    end)
    |> Map.new
  end

  defp persist state do
    state = Poison.encode!( state )
    File.write!(@persist, state)
    Logger.info('HEATER: Saved state.')
  end

end
