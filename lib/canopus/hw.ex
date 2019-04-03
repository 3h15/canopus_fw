defmodule Canopus.HW do

  #  pins des relais:
  #
  #   Lingerie <- 09 || 25 -> 1ET Chambre SE
  # Chambre SO <- 10 || 26 -> 1ET Chambre NE
  # Chambre NO <- 11 || 27 -> RDC SDB
  #               12 || 28 -> RDC Chambre
  #               13 || 29 -> RDC Entrée
  #               14 || 30 -> RDC Petit salon
  #               15 || 31 -> RDC Grand salon N & S, non branché parce qu'il n'y a pas d'electrovanne pour l'instant
  #     Heater <- 16 || 32 -> RDC Cuisine


  # Structure of hardware. Order is important

  @rooms [


    %{
      label: "Salon",
      sensor_id: :f,
      valves: [31],
    },
    %{
      label: "Petit salon",
      sensor_id: :c,
      valves: [30],
    },
    %{
      label: "Cuisine",
      sensor_id: :j,
      valves: [32],
    },
    %{
      label: "Entrée",
      sensor_id: :d,
      valves: [29],
    },
    %{
      label: "Chambre des parents",
      sensor_id: :a,
      valves: [28],
    },
    %{
      label: "S. de bain des parents",
      sensor_id: :b,
      valves: [27],
    },
    %{
      label: "Chambre de Suzanne",
      sensor_id: :e,
      valves: [11],
    },
    %{
      label: "Chambre de Félix",
      sensor_id: :h,
      valves: [25],
    },
    %{
      label: "Chambre de Zacharie",
      sensor_id: :g,
      valves: [26],
    },
    %{
      label: "Chambre de Judith",
      sensor_id: :i,
      valves: [10],
    },
    %{
      label: "Chambre d'amis",
      sensor_id: :k,
      valves: [],
    },

  ]

  def get_all, do: @rooms

  def get_by_sensor_id(sensor_id) when is_binary(sensor_id) do
    sensor_id = sensor_id |> String.downcase |> String.to_existing_atom
    get_by_sensor_id(sensor_id)
  end

  def get_by_sensor_id(sensor_id) when is_atom(sensor_id) do
    Enum.find(@rooms, fn(room) -> room.sensor_id == sensor_id end)
  end

end
