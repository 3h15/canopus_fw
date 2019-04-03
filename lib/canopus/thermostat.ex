defmodule Canopus.Thermostat do

  @persist "/root/rooms.json"
  
  use GenServer
  require Logger


  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def init(_) do
    Logger.metadata(service: :thermostat)
    # Room structure
    room = %{
      temperature: 0.0,
      target_temperature: 0.0,
      heating_is_on: false,
      last_update_time: "",
      longest_interval: 0,
      average_interval: 0,
      hit_count: 0,
    }
    # List of rooms
    state = %{a: room, b: room, c: room, d: room, e: room, f: room, g: room, h: room, i: room, j: room, k: room}

    # Update with data from disk
    state = read_data_from_disk(state)
    
    {:ok, state}
  end

  def handle_call( {:set_target_temperature, sensor_id, target_temperature}, _from, state ) do
    # Get atom from sensor id binary
    sensor_id = sensor_id |> String.downcase |> String.to_existing_atom

    # Get room's map and update it
    room = state[sensor_id]
    room = %{room | target_temperature: target_temperature}

    # Put map back into state
    state = state |> Map.put(sensor_id, room)

    state = state |> adjust_heating

    # Persist state
    persist( state )

    {:reply, state[sensor_id], state}
  end

  def handle_call( {:update_sensor, sensor_id, temperature}, _from, state ) do
    # Get atom from sensor id binary
    sensor_id = sensor_id |> String.downcase |> String.to_existing_atom
    # Get correponding room map
    room = state[sensor_id]

    # Compute timings and hit count
    now = Canopus.Clock.clock_time
    last_update_time = case DateTime.from_iso8601(room.last_update_time) do
      {:ok, date, _} -> date
      {:error, _} -> now
    end
    last_interval = DateTime.diff now, last_update_time
    average_interval = (room.average_interval * room.hit_count + last_interval) / (room.hit_count + 1);

    room = %{room | last_update_time: DateTime.to_iso8601( now )}
    room = %{room | hit_count: (room.hit_count + 1)}
    room = %{room | average_interval: average_interval}

    room =
      case room.longest_interval < last_interval do
        true -> %{room | longest_interval: last_interval}
        false -> room
      end

    # Compute temperature
    temperature = String.to_integer(temperature) / 100

    # Get room's map and update it
    room = %{room | temperature: temperature}

    # Put map back into state
    state = state |> Map.put(sensor_id, room)

    state = state |> adjust_heating

    # Persist state
    persist( state )

    {:reply, :done, state}
  end

  def handle_call( :get_all, _from, state ) do
    {:reply, state, state}
  end

  def handle_call( {:get, sensor_id}, _from, state ) do
    {:reply, state[sensor_id], state}
  end

  def handle_call( :get_average_temperature, _from, state ) do
    # Get a list of rooms 
    rooms = state |> Map.values

    # Compute averages
    avg_temperature = Enum.reduce(rooms, 0, fn(r, s) -> s + r.temperature end) / Enum.count(rooms)
    
    {:reply, avg_temperature, state}
  end

  defp adjust_heating( state ) do
    # Reset all rooms
    state = state |> Enum.map(fn({k, v})->
      {k, Map.put(v, :heating_is_on, false)}
    end)
    |> Map.new
    
    # Find the rooms that needs heating
    # We sort them by their difference to target temp
    # And keep the 2 first rooms
    # This ensure we are always heating 2 rooms which protects pumps
    [room_1_id, room_2_id] = state
    |> Enum.sort_by(fn({_k, room})->
      room.temperature - room.target_temperature
    end)
    |> Enum.slice(0..1)
    |> Enum.map(fn({k, _v})->k end)

    # Set heeating flag in rooms
    room_1 = state[room_1_id] |> Map.put(:heating_is_on, true)
    room_2 = state[room_2_id] |> Map.put(:heating_is_on, true)
    
    # Put rooms back into state
    state = state |> Map.put(room_1_id, room_1)
    state = state |> Map.put(room_2_id, room_2)

    # Open and close valves
    Enum.each(state, fn({room_id, room})->
      valves = Canopus.HW.get_by_sensor_id(room_id).valves
      valveState = case room.heating_is_on do
        # :off valve closed, :on valve open
        # In case of error, keep valve opened for security  
         false -> :off
         _ -> :on
      end
      Enum.each(valves, fn(valve_pin)->
        GenServer.call(Canopus.I2c, %{pin: valve_pin, to: valveState})
      end)
    end)
    
    state
  end



  defp read_data_from_disk state do
    with {:ok, json} <- File.read(@persist),
         {:ok, persisted_state} <- Poison.decode(json) do
      Logger.info('Loaded persisted state.')
      read_persisted_state(state, persisted_state)
    else
      _ -> Logger.info('Unable to load persisted state.')
        state
    end
  end

  defp read_persisted_state state, persisted_state do
    # Reads persisted state and copy values to state
    # We copy values one by one, using state structure to get the values
    # This way, we avoid any json corruption to survive a reboot
    # and removed properties won't stay in file forever.
    state
    |> Enum.map( fn( {id, room} ) ->
      {
        id,
        room
        |> Enum.map( fn( {key, value} ) ->
          persisted_value = persisted_state[to_string(id)][to_string(key)]
          {key, persisted_value || value}
        end)
        |> Map.new
      }
    end)
    |> Map.new
  end

  defp persist state do
    state = Poison.encode!( state )
    File.write!(@persist, state)
    Logger.info('Saved state.')
  end
  
end