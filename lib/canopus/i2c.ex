defmodule Canopus.I2c do

  use GenServer
  require Logger

  use Bitwise, only_operators: true

  # I2C bus name
  @bus_name "i2c-1"

  # IC addresses
  @ic_1   0x20
  @ic_2   0x21
  @clock  0x68

  # CLOCK REGISTERS
  # @seconds  0x00
  # @minutes  0x01
  # @hours    0x02
  # @day      0x03
  # @date     0x04
  # @month    0x05
  # @year     0x06
  # @control  0x07

  # IO COMMANDS

  # Set input(1)/output(0) mode
  @io_dir_a 0x00  # A Range (1->8)
  @io_dir_b 0x01  # B Range (9->16)

  # Data. read/write data
  @gpio_a 0x12  # A Range (1->8)
  @gpio_b 0x13  # B Range (9->16)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: Canopus.I2c)
  end

  def init(_) do
    # Logger.metadata(service: :i2c)

    # Connect i2c
    {:ok, bus} = Circuits.I2C.open(@bus_name)
    Logger.info("I2C started.")

    # Set all pins to output
    Circuits.I2C.write(bus, @ic_1, <<@io_dir_a, 0x00>>)
    Circuits.I2C.write(bus, @ic_1, <<@io_dir_b, 0x00>>)
    Circuits.I2C.write(bus, @ic_2, <<@io_dir_a, 0x00>>)
    Circuits.I2C.write(bus, @ic_2, <<@io_dir_b, 0x00>>)
    Logger.info("All pins to OUTPUT.")

    # Set all pins to 0
    write({bus, 0})
    Logger.info("All pins to 0.")

    {:ok, {bus, 0}}
  end

  # CLOCK
  def handle_call( :get_date, _from, {bus, state} ) do
    # Read 7 bytes from address <<0>>
    {:ok, data} = Circuits.I2C.write_read(bus, @clock, <<0>>, 7)
    {:reply, data, {bus, state}}
  end

  def handle_call( {:set_date, data}, _from, {bus, state} ) do
    # Add start address in front of data (first byte sent is start address)
    data = <<0>> <> data
    Circuits.I2C.write(bus, @clock, data)
    {:reply, nil, {bus, state}}
  end

  # IO PI
  def handle_call( %{pin: pin_number, to: value}, _from, {bus, data} ) do
    pin = 1 <<< (pin_number - 1)

    data = merge(data, pin, value)
    write({bus, data})

    {:reply, data, {bus, data}}
  end

  defp merge(data, pin, :on), do: data ||| pin
  defp merge(data, pin, :off), do: data &&& ~~~pin

  # Write 32 bits to the bus at once
  defp write({bus, data}) do
    <<byte_4, byte_3, byte_2, byte_1>> = << data :: size(32) >>
    Circuits.I2C.write(bus, @ic_1, <<@gpio_a, byte_1>>)
    Circuits.I2C.write(bus, @ic_1, <<@gpio_b, byte_2>>)
    Circuits.I2C.write(bus, @ic_2, <<@gpio_a, byte_3>>)
    Circuits.I2C.write(bus, @ic_2, <<@gpio_b, byte_4>>)
    log = data |> Integer.to_string(2) |> String.pad_leading(32, "0")
    Logger.info("Written #{log}")
  end

end
