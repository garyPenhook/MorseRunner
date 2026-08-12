# Morse Runner — Native Linux

Morse Runner is a native Linux CW contest simulator for practicing pile-ups,
single calls, WPX competition, and HST competition. It runs as a Linux ELF
application with a GTK3 interface and PulseAudio/PipeWire-compatible audio;
it does not use Wine or Windows libraries.

The production engine is based on the maintained WU6P native Linux/macOS port.
This repository adds reviewed Linux integration overlays, packaging, and
documentation around that engine.

## Build and run

Clone the repository with its pinned native engine, then build the production
application:

```sh
git submodule update --init --recursive
make bootstrap-toolchain
make linux-app
./build/bin/morserunner-linux
```

The build bootstrap fetches Lazarus at the reviewed commit recorded in
`scripts/bootstrap-toolchain.sh`. On a Debian-family host, install Free Pascal
and the required system headers if they are absent:

```sh
sudo apt install build-essential fpc make git pkg-config libgtk-3-dev libpulse-dev
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

This installs `morserunner` (with `morserunner-linux` retained as an alias),
a freedesktop.org desktop entry, an icon, the contest data, and the full
native engine.

### Run the portable AppImage

Download `MorseRunner-<version>-x86_64.AppImage` from the
[GitHub Releases](https://github.com/garyPenhook/MorseRunner/releases) page,
make it executable, and run it without installing anything system-wide:

```sh
chmod +x MorseRunner-*-x86_64.AppImage
./MorseRunner-*-x86_64.AppImage
```

The AppImage is built for x86_64 Linux systems. It keeps user settings and
recordings in the same XDG locations as the installed application.

### Release artifacts

Build a Debian package and validate its extracted installation layout:

```sh
make deb-test
```

The result is `build/packages/morserunner-linux_1.85.8_amd64.deb`. Build the
portable x86_64 AppImage. The build downloads pinned-checksum copies of
`linuxdeploy` and `appimagetool`, then uses `linuxdeploy` to deploy the engine's
shared-library dependencies before assembly. A changed upstream download fails
closed:

```sh
make appimage-test
```

For a release intended to run on older supported distributions, build the
AppImage in the Debian 11 container rather than on the developer host. This
uses glibc 2.31, bundles non-base runtime libraries, and launches the result
under Xvfb:

```sh
make container-release
```

`make container-test` runs the core suite, production build, and Debian-package
startup test in the same baseline image. Docker or a compatible container
runtime is required for these two portability gates.

### Desktop integration

Morse Runner installs a custom telegraph-key icon for the application menu,
task switcher, window title bar, and dock. The desktop entry uses a direct icon
path and declares its GTK window class so the icon resolves consistently in
KDE Plasma and other freedesktop-compliant desktops.

## Multi-caller speed range

For pile-up practice, set **Activity** to `2` or higher and use the two
**Caller WPM range** fields in the Station panel. Every newly-created caller
then receives an independent random whole-number speed from the inclusive
range—for example, `28` through `35` WPM. The range is saved with your other
settings. The caller-speed floor is `28` WPM; use each field's up/down spinner
buttons to adjust the limits.

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
