                         MORSE RUNNER — NATIVE LINUX PORT

                              Contest Simulator

  This repository ports Morse Runner 1.68 to a native Linux application. It
  retains the original Object Pascal simulation and Morse-audio behavior where
  practical, while replacing the Windows/VCL and WinMM boundaries with Lazarus
  LCL and PortAudio. Windows is not a supported target for this repository.

  The original application was written by Alex Shovkoplyas, VE3NEA:
  http://www.dxatlas.com/MorseRunner/


PORT STATUS

  The port is under active development. The current native Linux foundation
  includes:

  - a GTK3 Lazarus native-preview executable that plays a default-device CQ
    loop through PortAudio and can queue operator-entered Morse text;
  - headless settings/XDG persistence, timing, logging/scoring,
    contest-session, PCM-ring, legacy PCM conversion, and Morse-keyer core
    units;
  - a PortAudio 19 output boundary that consumes preallocated PCM blocks; and
  - direct Free Pascal and Lazarus test projects.

  It is not yet a complete replacement for the historic application: station
  simulation/DSP integration, full contest UI migration, actual playback-frame
  clock reporting, recording, and Linux packaging are still in progress. The
  GUI timer polls callback-reported frames; it is not a simulation clock.


PLATFORM

  - Native Linux x86-64 is the supported development target.
  - The application builds with Free Pascal 3.2.2, Lazarus 4.8, and the GTK3
    widgetset.
  - PortAudio 19 is the initial output backend, intended to work through the
    host's PipeWire or PulseAudio compatibility layer.
  - Wayland and X11 are release targets; GTK3 runtime validation is still
    pending.


BUILDING AND TESTING

  The repository includes project-local toolchain support and wrapper targets:

    make core-test
    make lazarus-core-test
    make linux-app
    make audio-smoke-test

  The first two compile and run the headless test suite. The last creates the
  native GTK3 executable at:

    build/bin/morserunner-linux

  audio-smoke-test is opt-in: it opens the default PortAudio output device and
  plays a short block of silence to validate stream startup and callback sizing.

  The current native window lets you set your callsign, CW speed, pitch, and
  session duration before Start. Once running, enter text in the transmit field
  and click "Transmit text"; <my>, <his>, and <#> message placeholders are
  expanded before the queued message is keyed. This is a Morse-sender preview,
  not yet the original station/pile-up simulator.

  The extracted call-list service accepts legacy Master.dta and Super Check
  Partial MASTER.SCP format. To install the current worldwide contest list in
  your XDG data directory, run:

    make update-call-list

  The source file remains user-owned data rather than a repository snapshot.
  Future station simulation searches an explicitly configured file first, then
  $XDG_DATA_HOME/morserunner (or ~/.local/share), the current directory, and
  /usr/share/morserunner.

  Development requires PortAudio 19 and GTK3 development files. See
  LINUX_PORT_DESIGN.md for toolchain details, architecture decisions, current
  validation status, and the remaining migration plan.


CONFIGURATION NOTE

  Native settings are stored in:

    $XDG_CONFIG_HOME/morserunner/config.ini

  When XDG_CONFIG_HOME is not set, this defaults to:

    $HOME/.config/morserunner/config.ini

  On first launch the port imports MorseRunner.ini from the working directory
  or the executable directory when one is present, writes the normalized native
  configuration, and never writes back to the legacy file. The configuration
  descriptions below are retained as historical behavior documentation.



CONFIGURATION

  Station

    Call - enter your contest callsign here.

    QSK - simulates the semi-duplex operation of the radio. Enable it if your
      physical radio supports QSK. If it doesn't, enable QSK anyway to see
      what you are missing.

    CW Speed - select the CW speed, in WPM (PARIS system) that matches your
      skills. The calling stations will call you at about the same speed.

    CW Pitch - pitch in Hz.

    RX Bandwidth - the receiver bandwidth, in Hz.

    Audio Recording Enabled - when this menu option is checked, MR saves
      the audio in the MorseRunner.wav file. If this file already
      exists, MR overwrites it.



  Band Conditions

     I tried to make the sound as realistic as possible, and included a few
     effects based on the mathematical model of the ionospheric propagation.
     Also, some of the calling stations exhibit less then perfect operating
     skills, again to make the simulation more realistic. These effects can
     be turned on and off using the checkboxes described below.


     QRM - interference form other running stations occurs from time to time.

     QRN - electrostatic interference.

     QSB - signal strength varies with time (Rayleigh fading channel).

     Flutter - some stations have "auroral" sound.

     LIDS - some stations call you when you are working another station,
       make mistakes when they send code, copy your messages incorrectly,
       and send RST other than 599.

     Activity - band activity, determines how many stations on average
       reply to your CQ.



  Audio buffer size

    You can adjust the audio buffer size by changing the BufSize value in the
    MorseRunner.ini file. Acceptable values are 1 through 5, the default is 3.
    Increase the buffer size for smooth audio without clicks and interruptions;
    decrease the size for faster response to keyboard commands.


  Competition duration

    The default duration of a competition session is 60 minutes. You can set it
    to a smaller value by changing the CompetitionDuration entry in the
    MorseRunner.ini file, e.g.:

    [Contest]
    CompetitionDuration=15


  Calls From Keyer

    If you have an electronic keyer that simulates a keyboard - that is, sends
    all transmitted characters to the PC as if they were entered from a keyboard,
    you can add the following to the INI file:

    [Station]
    CallsFromKeyer=1

    With this option enabled, the callsign entered into the CALL field is not
    transmitted by the computer when the corresponding key is pressed. This option
    has no effect in the WPX and HST competition modes.




STARTING A CONTEST

The contest can be started in one of four modes.

 Pile-Up mode: a random number of stations calls you after you send a CQ. Good
   for improving copying skills.

 Single Calls mode: a single station calls you as soon as you finish the
   previous QSO. Good for improving typing skills.

 WPX Compteition mode: similar to the Pile-Up mode, but band conditions and contest
   duration are fixed and cannot be changed. The keying speed and band activity
   are still under your control;

 HST Competition mode: all settings conform to the IARU High Speed Telegraphy
   competition rules.



To start a contest, set the duration of the exercise in the Run for NN Minutes
box (only for Pile-Up and Single Calls modes), and click on the desired mode
in the Run button's menu. In the Pile-Up and Competition mode, hit F1 or Enter
to send a CQ.




KEY ASSIGNMENTS

  F1-F8 - sends one of the pre-defined messages. The buttons under the input
    fields have the same functions as these keys, and the captions
    of the buttons show what each key sends.

  "\" - equivalent to F1.

  Esc - stop sending.

  Alt-W, Ctrl-W, F11 - wipe the input fields.

  Alt-Enter, Shift-Enter, Ctrl-Enter - save QSO.


  <Space> - auto-complete input, jump between the input fields.

  <Tab>, Shift-<Tab> - move to the next/previous field.

  ";", <Ins> - equivalent to F5 + F2.

  "+", ".", ",", "[" - equivalent to F3 + Save.

  Enter - sends various messages, depending on the state of the QSO;

  Up/Down arrows - RIT;

  Ctrl-Up/Ctrl-Down arrows - bandwidth;

  PgUp/PgDn, Ctrl-F10/Ctrl-F9, Alt-F10/Alt-F9 - keying speed,
    in 5 WPM increments.



WPX COMPETITION RULES

The exchange consists of the RST and the serial number of the QSO.

The score is a product of points (# of QSO) and multiplier (# of different
prefixes).

The bottom right panel shows your current score, both Raw (calculated
from your log) and Verified (calculated after comparing your log to other
stations' logs). The histogram shows your raw QSO rate in 5-minute blocks.

The log window marks incorrect entries in your log as follows:

  DUP - duplicate QSO.

  NIL - not in other station's log: you made a mistake in the callsign, or forgot
    to send the corrected call to the station.

  RST - incorrect RST in your log.

  NR - incorrect exchange number in your log.





SUBMITTING YOUR SCORE

If you complete a full 60-minute session in the WPX Competition mode, Morse Runner
will generate a score string that you can post to the Score Board on the web:
<http://www.dxatlas.com/MorseRunner/MrScore.asp>. Copy and paste your score
string into the box on the web page and click on the Submit button.

You can view your previous score strings using the File -> View Score menu
command.






VERSION HISTORY


1.68
  - TU + MyCall after the QSO is now equivalent to CQ



1.67
  - small changes in the HST competition mode.



1.65, 1.66
  - a few small bugs fixed.



1.61 - 1.64
  - small changes in the HST competition mode.



1.6
  - HST competition mode added;
  - CallsFromKeyer option added.



1.52
  - the CompetitionDuration setting added.



1.51
  - minor bugs fixed.



1.5
  - more realistic behavior of calling stations;
  - self-monitoring volume control;
  - more creative LIDS;
  - CW speed hotkeys;
  - WAV recording;
  - menu commands for all settings (for blind hams).



1.4
  - RIT function;
  - callsign completion/correction when sending;
  - faster response to keyboard commands;
  - bandwidth adjustment in 50 Hz steps;
  - the middle digit is selected when the cursor enters the RST field;
  - the QSO rate is now expressed in Q/hr;
  - the problem with the Finnish character set fixed.


1.3

  - some key assignments corrected for compatibility with popular contesting
    programs;
  - statistical models refined for more realistic simulation;
  - rate display added;
  - a few bugs fixed.


1.2 (first public release)

  - Competetion mode added;
  - some bugs fixed.


1.1
  - ESM (Enter Sends Messages) mode added;
  - a lot of bugs fixed.
