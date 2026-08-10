# Morse Runner — Native Linux

Morse Runner is a native Linux CW contest simulator for practicing pile-ups,
single calls, WPX competition, and HST competition. It runs as a Linux ELF
application with a GTK3 interface and PulseAudio/PipeWire-compatible audio;
it does not use Wine or Windows libraries.

Linux port by Gary Scott, W4GNS.

## Build and run

Clone the repository with its pinned native engine, then build the production
application:

```sh
git submodule update --init --recursive
make linux-app
./build/bin/morserunner-linux
```

The repository includes the Free Pascal and Lazarus toolchain used by the
build. On a Debian-family host, install the system headers if they are absent:

```sh
sudo apt install build-essential pkg-config libgtk-3-dev libpulse-dev
```

The first session is easiest with **Run → Single Calls**. Set your call sign,
speed, and preferred exchange, then use the function-key messages while
practicing. The complete in-app guide is available through **Help → Readme**.

## Install on Linux

Install to `/usr/local`:

```sh
sudo make install
```

Or install for the current user without elevated privileges:

```sh
make install PREFIX="$HOME/.local"
```

This installs `morserunner-linux`, a freedesktop.org desktop entry, an icon,
the contest data, and the full native engine.

## Data and diagnostics

- The bundled `MASTER.SCP` Super Check Partial list supplies the callsigns.
- Settings, recordings, and HST results are stored in
  `$XDG_DATA_HOME/MorseRunner/` (normally `~/.local/share/MorseRunner/`).
- GTK3 backend diagnostics are retained in
  `$XDG_STATE_HOME/morserunner/gtk3-runtime.log` (normally
  `~/.local/state/morserunner/`) without cluttering normal terminal launches.
- Set `MORSERUNNER_DEBUG=1` before launching to display those diagnostics in
  the terminal.

## Verification

```sh
make core-test
make linux-app
```

The full native engine is pinned in `native/engine`; small reviewed overlays
in `patches/` provide Linux-specific call-list, UI, and help integration.
Port design and migration decisions are documented in
[LINUX_PORT_DESIGN.md](LINUX_PORT_DESIGN.md).

## License and attribution

The project is licensed under MPL-2.0. It retains the original Morse Runner
work by Alex Shovkoplyas, VE3NEA, and incorporates the maintained native-port
work credited in the application and source history.
