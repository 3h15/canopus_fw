defmodule Canopus.Thermostat do

  @persist "/root/rooms.json"

  use GenServer
  require Logger


  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
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
    rooms = %{a: room, b: room, c: room, d: room, e: room, f: room, g: room, h: room, i: room, j: room, k: room}

    # State
    state = %{
      rooms: rooms,
      n_sim_open: 2
    }

    # Update with data from disk
    state = read_data_from_disk(state)

    state = adjust_heating(state)

    {:ok, state}
  end

  def handle_call( {:set_target_temperature, sensor_ref, target_temperature}, _from, state ) do
    # Get atom from sensor id binary
    sensor_id = Canopus.HW.sensor_id(sensor_ref)

    # Get room's map and update it
    room = state.rooms[sensor_id]
    room = %{room | target_temperature: target_temperature}

    # Put map back into state
    state = put_in state.rooms[sensor_id], room

    state = state |> adjust_heating

    # Persist state
    persist( state )

    {:reply, state.rooms[sensor_id], state}
  end

  def handle_call( {:set_n_sim_open, value}, _from, state ) do

    value = case value do
      x when x < 2 -> 2
      x -> x
    end
    state = %{state | n_sim_open: value}
    state = state |> adjust_heating

    # Persist state
    persist( state )

    {:reply, value, state}
  end

  def handle_call( {:update_sensor, sensor_ref, temperature}, _from, state ) do
    # Get atom from sensor id binary
    sensor_id = Canopus.HW.sensor_id(sensor_ref)
    # Get corresponding room map
    room = state.rooms[sensor_id]

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
    state = put_in state.rooms[sensor_id], room

    state = state |> adjust_heating

    # Persist state
    persist( state )

    {:reply, :done, state}
  end

  def handle_call( :get_all, _from, state ) do
    {:reply, state.rooms, state}
  end

  def handle_call( {:get, sensor_id}, _from, state ) do
    {:reply, state.rooms[sensor_id], state}
  end

  def handle_call( :get_average_temperature, _from, state ) do
    # Get a list of rooms
    rooms = state.rooms |> Map.values

    # Compute averages
    avg_temperature = Enum.reduce(rooms, 0, fn(r, s) -> s + r.temperature end) / Enum.count(rooms)

    {:reply, avg_temperature, state}
  end

  def handle_call( :get_n_sim_open, _from, state ) do
    {:reply, state.n_sim_open, state}
  end

  defp adjust_heating( state ) do
    # Reset all rooms
    rooms = state.rooms |> Enum.map(fn({k, v})->
      {k, Map.put(v, :heating_is_on, false)}
    end)
    |> Map.new

    n_sim_open = state.n_sim_open - 1

    # Find the rooms that needs heating
    # We sort them by their difference to target temp
    # And keep the 2 first rooms
    # This ensure we are always heating 2 rooms which protects pumps
    ids_to_open = rooms
    |> Enum.sort_by(fn({_k, room})->
      room.temperature - room.target_temperature
    end)
    |> Enum.slice(0..n_sim_open)
    |> Enum.map(fn({k, _v})->k end)

    rooms = ids_to_open
    |> Enum.reduce( rooms, fn(id_to_open, rooms)->
      # Set heating flag in room
      room = rooms[id_to_open] |> Map.put(:heating_is_on, true)
      # Put rooms back into state
      rooms |> Map.put(id_to_open, room)
    end)

    # Open and close valves
    Enum.each(rooms, fn({room_id, room})->
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

    %{state | rooms: rooms}
  end



  defp read_data_from_disk state do
    with {:ok, json} <- File.read(@persist),
         {:ok, persisted_state} <- Poison.decode(json) do
      Logger.info('THERMOSTAT: Loaded persisted state.')
      read_persisted_state(state, persisted_state)
    else
      _ -> Logger.info('THERMOSTAT: Unable to load persisted state.')
        state
    end
  end

  defp read_persisted_state state, persisted_state do
    # Reads persisted state and copy values to state
    # We copy values one by one, using state structure to get the values
    # This way, we avoid any json corruption to survive a reboot
    # and removed properties won't stay in file forever.
    rooms = case persisted_state |> Map.has_key?("rooms") do
      false -> state.rooms
      true  -> state.rooms |> read_persisted_rooms(persisted_state["rooms"])
    end
    n_sim_open = case persisted_state |> Map.has_key?("n_sim_open") do
      false -> state.n_sim_open
      true  -> persisted_state["n_sim_open"]
    end
    %{state | rooms: rooms, n_sim_open: n_sim_open}
  end

  defp read_persisted_rooms rooms, persisted_rooms do
    rooms |> Enum.map( fn( {id, room} ) ->
      {
        id,
        room |> Enum.map( fn( {key, value} ) ->
          persisted_value = persisted_rooms[to_string(id)][to_string(key)]
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
    Logger.info('THERMOSTAT: Saved state.')
  end

end
