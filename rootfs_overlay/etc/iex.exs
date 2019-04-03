# Add Toolshed helpers to the IEx session
use Toolshed

if RingLogger in Application.get_env(:logger, :backends, []) do
  IO.puts """
  CANOPUS

  Attach the current IEx session to the logger:
      RingLogger.attach

  Print the next messages in the log:

      RingLogger.next

  Filter the log:

      RingLogger.grep(~r/REGEX/)
      RingLogger.grep(~r/REGEX/i) (case insensitive)

  """
end

# Be careful when adding to this file. Nearly any error can crash the VM and
# cause a reboot.
