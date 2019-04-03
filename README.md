# Canopus


To build and install canopus on the rpi3:
  * Use asdf to install elixir and erlang.
  * Setup environment vars:
  * `export NERVES_NETWORK_SSID=NEMO`
  * `export NERVES_NETWORK_PSK=secret`
  * `export MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Burn to an SD card with `mix firmware.burn`
  * Upgrade firmware via SSH with `mix firmware.push 192.168.1.68`
  * Or use `./upload.sh` (Because firmware.push is broken for now)
  * Connect to iex on canopus with `ssh 192.168.1.68`