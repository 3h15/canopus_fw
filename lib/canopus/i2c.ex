defmodule Canopus.I2c do

  use GenServer
  require Logger

  alias ElixirALE.I2C

  use Bitwise, only_operators: true

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
    {:ok, pid} = I2C.start_link("i2c-1", 1)
    Logger.info("I2C started.")

    Logger.info("Devices:")
    I2C.detect_devices(pid)
    |> Enum.each(fn(item) ->
      item
      |> Integer.to_string(16)
      |> Logger.info
    end)

    # Set all pins to output
    I2C.write_device(pid, @ic_1, <<@io_dir_a, 0x00>>)
    I2C.write_device(pid, @ic_1, <<@io_dir_b, 0x00>>)
    I2C.write_device(pid, @ic_2, <<@io_dir_a, 0x00>>)
    I2C.write_device(pid, @ic_2, <<@io_dir_b, 0x00>>)
    Logger.info("All pins to OUTPUT.")

    # Set all pins to 0
    write({pid, 0})
    Logger.info("All pins to 0.")

    {:ok, {pid, 0}}
  end

  # CLOCK
  def handle_call( :get_date, _from, {pid, state} ) do
    # Read 7 bytes from address <<0>>
    data = I2C.write_read_device(pid, @clock, <<0>>, 7)
    {:reply, data, {pid, state}}
  end

  def handle_call( {:set_date, data}, _from, {pid, state} ) do
    # Add start address in front of data (first byte sent is start address)
    data = <<0>> <> data
    I2C.write_device(pid, @clock, data)
    {:reply, nil, {pid, state}}
  end

  # IO PI
  def handle_call( %{pin: pin_number, to: value}, _from, {pid, data} ) do
    pin = 1 <<< (pin_number - 1)

    data = merge(data, pin, value)
    {pid, data} |> write()

    {:reply, data, {pid, data}}
  end

  defp merge(data, pin, :on), do: data ||| pin
  defp merge(data, pin, :off), do: data &&& ~~~pin

  # Write 32 bits to the bus at once
  defp write({pid, data}) do
    <<byte_4, byte_3, byte_2, byte_1>> = << data :: size(32) >>
    I2C.write_device(pid, @ic_1, <<@gpio_a, byte_1>>)
    I2C.write_device(pid, @ic_1, <<@gpio_b, byte_2>>)
    I2C.write_device(pid, @ic_2, <<@gpio_a, byte_3>>)
    I2C.write_device(pid, @ic_2, <<@gpio_b, byte_4>>)
    log = data |> Integer.to_string(2) |> String.pad_leading(32, "0")
    Logger.info("Written #{log}")
  end

end
