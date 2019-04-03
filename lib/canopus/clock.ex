defmodule Canopus.Clock do

                      # DATA STRUCTURE
                      # BYTE 0:
  @ch  {0x80, 7}      #   7     Clock Halt. 1 = halt, 0 = count
  @sd1 {0x70, 4}      #   4-6   Seconds first digit
  @sd2 {0x0F, 0}      #   0-3   Seconds second digit
                      # BYTE 1
  @id1 {0xF0, 4}      #   4-7   Minutes first digit
  @id2 {0x0F, 0}      #   0-3   Minutes second digit
                      # BYTE 2
                      #   7     Unused
  @h24 {0x40, 6}      #   6     12/24H mode 1 = 12, 0 = 24
  @hd1 {0x30, 4}      #   4-5   Hours first digit (When using 24H mode. see datasheet)
  @hd2 {0x0F, 0}      #   0-3   Hours second digit
                      # BYTE 3
                      #   3-7   Unused
  @dw1 {0x03, 0}      #   0-2   Day of week
                      # BYTE 4
                      #   6-7   Unused
  @dd1 {0x30, 4}      #   4-5   Day of month first digit
  @dd2 {0x0F, 0}      #   0-3   Day of month second digit
                      # BYTE 5
                      #   5-7   Unused
  @md1 {0x10, 4}      #   4     Month first digit
  @md2 {0x0F, 0}      #   0-3   Month second digit
                      # BYTE 6
  @yd1 {0xF0, 4}      #   4-7   Year first digit
  @yd2 {0x0F, 0}      #   0-3   Year second digit

  use Bitwise, only_operators: true

  require Logger

  def clock_time() do
    <<b0, b1, b2, _b3, b4, b5, b6>> = GenServer.call(Canopus.I2c, :get_date)
    [
      "20",
      extract(b6, @yd1),
      extract(b6, @yd2),
      "-",
      extract(b5, @md1),
      extract(b5, @md2),
      "-",
      extract(b4, @dd1),
      extract(b4, @dd2),
      "T",
      extract(b2, @hd1),
      extract(b2, @hd2),
      ":",
      extract(b1, @id1),
      extract(b1, @id2),
      ":",
      extract(b0, @sd1),
      extract(b0, @sd2),
      "Z"
    ]
    |> Enum.join()
    |> Timex.parse!( "{ISO:Extended:Z}" )
  end

  def ntp_time do
    DateTime.utc_now
  end

  def ntp_to_clock do
    # "2017-10-04T16:40:16.049576Z"
    date = ntp_time() |> DateTime.to_iso8601

    yd1 = date |> String.slice(2, 1) |> String.to_integer
    yd2 = date |> String.slice(3, 1) |> String.to_integer
    md1 = date |> String.slice(5, 1) |> String.to_integer
    md2 = date |> String.slice(6, 1) |> String.to_integer
    dd1 = date |> String.slice(8, 1) |> String.to_integer
    dd2 = date |> String.slice(9, 1) |> String.to_integer

    hd1 = date |> String.slice(11, 1) |> String.to_integer
    hd2 = date |> String.slice(12, 1) |> String.to_integer
    id1 = date |> String.slice(14, 1) |> String.to_integer
    id2 = date |> String.slice(15, 1) |> String.to_integer
    sd1 = date |> String.slice(17, 1) |> String.to_integer
    sd2 = date |> String.slice(18, 1) |> String.to_integer

    b0 = group([ {0, @ch}, {sd1, @sd1}, {sd2, @sd2} ])
    b1 = group([ {id1, @id1}, {id2, @id2} ])
    b2 = group([ {0, @h24}, {hd1, @hd1}, {hd2, @hd2} ])
    b3 = group([ {0, @dw1} ])
    b4 = group([ {dd1, @dd1}, {dd2, @dd2} ])
    b5 = group([ {md1, @md1}, {md2, @md2} ])
    b6 = group([ {yd1, @yd1}, {yd2, @yd2} ])

    GenServer.call(Canopus.I2c, {:set_date, <<b0, b1, b2, b3, b4, b5, b6>>})
  end

  def in_paris_tz date do
    tz = Timex.timezone( "Europe/Paris", date )
    Timex.Timezone.convert(date, tz)
  end

  def minutes_from_now date do
    date = Timex.parse!(date, "{ISO:Extended:Z}" )
    now = clock_time()
    Timex.diff(now, date, :minutes)
  end

  defp extract byte, {mask, shift} do
    ((byte &&& mask) >>> shift) |> Integer.to_string(10)
  end

  defp group values do
    # Logger.debug("VALUES")
    # Logger.debug(IO.inspect(values))
    # Logger.debug("/VALUES")
    values |> Enum.reduce(0, fn({value, {mask, shift}}, acc)->
      # Logger.debug("acc, value, mask, shift")
      # Logger.debug(IO.inspect acc)
      # Logger.debug(IO.inspect value)
      # Logger.debug(IO.inspect mask)
      # Logger.debug(IO.inspect shift)
      ((value <<< shift) &&& mask) ||| acc
    end)
  end


end
