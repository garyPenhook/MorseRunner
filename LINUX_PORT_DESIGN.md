# Morse Runner Native Linux Port Design

Status: In progress

Last updated: 2026-08-10

Target repository: https://github.com/garyPenhook/MorseRunner

License: Mozilla Public License 2.0

## 1. Summary

Morse Runner will become a native Linux desktop application while preserving
the contest simulation, Morse generation, propagation effects, scoring, and
keyboard-centered workflow of version 1.68.

The recommended implementation is an incremental Object Pascal port:

- Free Pascal 3.2.2.
- Lazarus 4.8.
- Lazarus Component Library with the GTK3 widgetset.
- PortAudio for the first production audio backend.
- FPCUnit for unit and headless integration tests.
- XDG-compliant configuration, state, and data locations.

This is not a mechanical VCL-to-LCL form conversion. The original application
uses the Windows audio callback as its simulation clock and allows simulation
code to modify form controls directly. The port must first establish explicit
boundaries between the user interface, simulation engine, audio transport,
recording, and persistence.

The current Linux build includes a deliberately narrow, tested single-caller
practice loop. It selects a real callsign from the bundled Super Check Partial
list, sends `DE <caller> <caller>`, accepts a transmitted `<his> <#>` exchange,
answers with `R 599nnn`, logs a verified QSO after `TU` or `TNX`, and advances
to the next database caller. This is a working vertical slice, not a replacement for the original pile-up station
simulator; bringing that simulator across remains the next major porting task.

An existing Lazarus/PortAudio fork and the Debian morserunner package provide
useful conversion work. Their forms, compiler fixes, call-list data, desktop
integration, and packaging should be imported with attribution. Their
pre-alpha audio and threading implementation must not be adopted unchanged.

## 2. Goals

The port must:

1. Run as a native Linux ELF executable without Wine or Windows libraries.
2. Preserve Pile-Up, Single Calls, WPX Competition, and HST Competition modes.
3. Preserve the documented keyboard-first contest workflow.
4. Preserve the characteristic audio and statistical behavior of version 1.68.
5. Run correctly under both Wayland and X11.
6. Work on PipeWire and PulseAudio desktops through PortAudio and the host
   audio compatibility layer.
7. Use Linux desktop conventions for configuration, state, data, launchers,
   icons, and documentation.
8. Provide deterministic, headless tests for the simulation and scoring logic.
9. Support x86-64 for the first stable release and remain cleanly portable to
   AArch64.
10. Provide a reproducible command-line build and continuous integration.

## 3. Non-goals

The first native release will not:

- Preserve or add Windows support.
- Preserve macOS support.
- Maintain conditional Win32 or WinMM implementations.
- Rewrite the application in C++, Rust, JavaScript, or Python.
- Redesign the contest rules or add new contest modes.
- Replace the original DSP algorithms before compatibility tests exist.
- Require native PipeWire API integration.
- Require Flatpak as the first distribution format.
- Guarantee bit-identical floating-point PCM across CPU architectures.

## 4. Source Assessment

The original source contains approximately 8,200 lines across 29 Pascal units,
two Delphi forms, and Windows resources.

### 4.1 Reusable simulation and DSP code

The following units contain mostly platform-independent behavior:

- Station.pas
- StnColl.pas
- DxOper.pas
- DxStn.pas
- MyStn.pas
- QrmStn.pas
- QrnStn.pas
- Qsb.pas
- RndFunc.pas
- VCL/MorseKey.pas
- VCL/MorseTbl.pas
- VCL/MovAvg.pas
- VCL/QuickAvg.pas
- VCL/Mixers.pas
- VCL/VolumCtl.pas

These units should be retained initially, compiled with Free Pascal, covered by
tests, and simplified only after behavior has been locked down.

### 4.2 Coupled units requiring refactoring

Contest.pas owns the central simulation but also:

- Reads volume from MainForm.
- Writes WAV samples through a form component.
- Edits the log display.
- Updates time and pile-up controls.
- Stops sessions and opens score dialogs.

Log.pas combines the QSO model, scoring rules, formatted presentation, canvas
drawing, and direct form mutations.

Ini.pas combines settings serialization with widget initialization and
simulation object mutation.

CallLst.pas assumes a data file beside the executable and uses pointer-based
parsing with Delphi-era string assumptions.

SndTypes.pas includes WinMM types even though its numeric sample and complex
array types are otherwise reusable.

### 4.3 Units to replace

The following implementations are Windows-specific or obsolete:

- Main.pas and Main.dfm
- ScoreDlg.pas and ScoreDlg.dfm
- VCL/SndCustm.pas
- VCL/SndOut.pas
- VCL/WavFile.pas
- VCL/BaseComp.pas
- VCL/PermHint.pas
- VCL/VolmSldr.pas, if a standard LCL control is sufficient
- Windows RES and DCR design-time resources

### 4.4 Portability hazards

The port must audit and remove:

- Pointer-to-Integer and pointer-to-DWORD conversions.
- Assignments such as Integer(Result) := 0 on dynamic arrays.
- Assumptions that Integer and pointers have equal width.
- Win32 virtual key and modifier polling.
- Windows messages used as cross-thread notifications.
- TThread.Resume and unsafe FreeOnTerminate ownership.
- GUI calls made outside the GTK main thread.
- Allocation, locking, logging, or GUI calls in the audio callback.
- Implicit ANSI string and filesystem encoding assumptions.
- Paths derived from ParamStr(0) for writable files.

## 5. Existing Native Linux Work

The fritzsche/MorseRunner fork is based on an earlier Lazarus conversion and
shares history with the original repository. It supplies:

- Lazarus project and form files.
- Basic FPC compatibility changes.
- A Pascal PortAudio declaration unit.
- A Master.dta call-list file.
- Linux-oriented form layout changes.

The Debian package adds:

- A desktop launcher and icon.
- A system data location for Master.dta.
- XDG-oriented configuration storage.
- Reproducible Debian build rules.
- Current Debian Hamradio Maintainer ownership.

These changes should be imported through Git history or clearly attributed
commits instead of copied without provenance.

The existing audio implementation is explicitly pre-alpha and contains design
problems that the new port must replace:

- A global audio object.
- One shared mutable buffer and a non-atomic used flag.
- A polling worker with a fixed 10 ms sleep.
- Synchronize calls to generate audio on the GUI thread.
- Audio callback access to shared dynamic arrays.
- Incomplete stream close and PortAudio termination lifecycle.
- A hard-coded frame size that mutates simulation settings at startup.

## 6. Technology Decisions

### 6.1 Language and compiler

Keep Object Pascal and compile with Free Pascal 3.2.2. This minimizes behavioral
risk, preserves the original algorithms, and avoids translating approximately
two decades of simulation behavior into another language.

Use one explicit language mode throughout the project. Delphi mode is preferred
for compatibility with the source:

    {$mode delphi}{$H+}

Do not mix ObjFPC and Delphi modes without a documented unit-specific reason.

### 6.2 GUI toolkit

Use Lazarus 4.8 LCL with GTK3.

Rationale:

- GTK3 is packaged on current Debian-family systems.
- Lazarus made GTK3 its default Linux widgetset in its main development branch
  in July 2026.
- It supports Wayland and X11.
- It avoids the deprecated GTK2 dependency.
- It avoids making Qt5 a new long-term dependency.
- LCL Qt6 exists, but distro packaging is less consistent than GTK3 today.

Keep the UI within ordinary LCL APIs so a future Qt6 build remains possible,
but do not make multi-widgetset support a first-release requirement.

### 6.3 Audio API

Use PortAudio 19 initially.

PortAudio is already used by the native fork and Debian package, is readily
packaged, and gives the project a stable device abstraction. It must be hidden
behind a small application-owned interface so that a native PipeWire backend
can be added later without affecting the simulation engine.

The audio interface should expose operations equivalent to:

    type
      IAudioOutput = interface
        procedure Open(const AFormat: TAudioFormat);
        procedure Start;
        procedure Stop;
        procedure Abort;
        procedure Close;
        function Stats: TAudioStats;
      end;

The exact Pascal interface declaration can evolve during implementation. The
ownership and lifecycle semantics may not.

### 6.4 WAV recording

Recording belongs downstream of simulation rendering and upstream of sample
format conversion. The writer receives the same rendered mono sample blocks
that feed the audio ring.

Use either:

1. A small project-owned PCM RIFF writer with explicit little-endian encoding;
   or
2. libsndfile if broader formats or metadata become requirements.

For the first release, a tested PCM RIFF writer is sufficient and avoids
another runtime dependency.

### 6.5 Persistence

Use the XDG Base Directory specification:

- Configuration: XDG_CONFIG_HOME/morserunner/config.ini
- Persistent scores and session history:
  XDG_STATE_HOME/morserunner/
- User recordings and imported data:
  XDG_DATA_HOME/morserunner/
- Packaged read-only data: /usr/share/morserunner/

Use the standard XDG defaults when an environment variable is absent.

On first launch, optionally import a legacy MorseRunner.ini found in the
current directory or beside the executable. Never continue writing there.

Current implementation: TContestSettingsStore writes typed settings to the
XDG configuration location, normalizes values both before writing and after
reading, and performs that legacy import only when no native configuration is
present. The old Ini.pas globals remain in the historical VCL source tree and
are not used by the Linux executable.

## 7. Runtime Architecture

### 7.1 Components

The application will have these logical components:

1. TApplicationController
   - Coordinates startup, shutdown, session transitions, and error reporting.
   - Owns the UI-facing command and event paths.

2. TContestEngine
   - Owns contest state, stations, keyer, DSP state, QSO model, and sample clock.
   - Has no dependency on Forms, Controls, Graphics, Dialogs, or Main.
   - Runs only on the simulation producer thread while a session is active.

3. TAudioProducer
   - Processes pending commands.
   - Calls TContestEngine.RenderBlock.
   - Pushes rendered blocks to a bounded PCM ring.
   - Sends immutable state snapshots and events to the UI queue.

4. TPortAudioOutput
   - Owns PortAudio initialization, stream, callback, and teardown.
   - Consumes from the PCM ring.
   - Atomically tracks frames handed to the device, underruns, and callback
     errors; the controller drains frame deltas outside the callback.

5. TWavRecorder
   - Receives rendered blocks from the producer.
   - Never runs in the PortAudio callback.
   - Finalizes headers on normal stop and best-effort shutdown.

6. TSettingsStore
   - Reads and writes typed settings.
   - Has no form or contest dependency.

7. TScoreModel and TQsoLog
   - Own QSO entries, duplicate/error checking, scoring, rate history, and
     formatted export data.
   - Do not paint controls or canvases.

8. TMainForm
   - Converts user actions into commands.
   - Applies snapshots and events on the GTK main thread.
   - Contains no contest rules or DSP behavior.

### 7.2 Ownership

- The application controller owns long-lived services.
- The simulation worker exclusively owns the contest engine during a run.
- The PortAudio object exclusively owns its native stream handle.
- The producer owns writable PCM blocks until they are committed to the ring.
- The callback owns a committed ring slot only while copying it.
- UI snapshots are immutable after publication.
- The GTK thread is the only thread allowed to access LCL objects.
- Shutdown joins worker threads before destroying their dependencies.

FreeOnTerminate should not be used for application-owned threads.

### 7.3 Command flow

UI actions become typed commands, for example:

- StartSession
- StopSession
- SendMessage
- AbortSend
- SaveQso
- WipeEntry
- SetCall
- SetWpm
- SetPitch
- SetBandwidth
- SetRit
- SetQsk
- SetBandConditions
- SetMonitorLevel
- SetRecording

Commands are applied between rendered audio blocks. At the legacy default of
512 frames and 11,025 Hz, this bounds command application delay to about
46.4 ms before downstream audio buffering.

The queue must be bounded. Overflow is an application error that is counted and
reported; it must not silently allocate an unbounded list.

### 7.4 Event flow

The engine publishes typed events such as:

- SessionStarted
- SessionStopped
- ContestTimeChanged
- QsoAdded
- QsoCorrected
- ScoreChanged
- RateChanged
- PileupCountChanged
- EntryFieldsRequested
- ScoreDialogRequested
- AudioError
- RecordingError

Frequently changing display state may be combined into a snapshot applied by a
30 Hz UI timer. Important one-shot events must remain queued and ordered.

### 7.5 Simulation clock

The canonical contest clock is the count of audio frames accepted for playback:

    contest_seconds = consumed_frames / sample_rate

The producer may render ahead only by the bounded ring capacity. Engine state
must never advance without a corresponding block that is committed for
playback, except during explicit headless test execution.

The displayed clock may lag by at most one UI refresh interval, but the session
end condition must use the canonical sample clock.

This prevents callback storms or producer loops from making the contest run
faster than audible playback.

## 8. Real-time Audio Design

### 8.1 PCM format

Initial compatibility format:

- Mono.
- 11,025 samples per second.
- Internal samples as Single.
- PortAudio output as signed 16-bit PCM.
- Default engine block size of 512 frames.

Keep the existing sample rate until compatibility tests exist. A later 48 kHz
mode would require retuning filters, envelopes, rates, and reference tests.

### 8.2 Ring buffer

Use a fixed-capacity single-producer/single-consumer ring. Its storage and every
sample block are allocated before the stream starts.

Recommended initial capacity: 4 to 8 blocks. Determine the final default from
latency and underrun measurements.

The producer:

1. Waits for a writable slot using a condition/event outside the callback.
2. Renders directly into or copies into the slot.
3. Publishes the slot with release ordering.

The callback:

1. Acquires the next readable slot.
2. Copies samples to PortAudio output.
3. Releases the slot.
4. Emits zero samples and increments an underrun counter if no slot is ready.
5. Atomically publishes the completed block's frame count for the controller.

The callback may not:

- Allocate or resize dynamic arrays.
- Acquire a blocking mutex.
- Call Synchronize, Queue, or any LCL function.
- Run contest or scoring logic.
- Write to disk or standard output.
- Raise an exception across the C callback boundary.
- Call PortAudio control functions.

The controller calls TakePlayedFrames outside the callback and passes that
delta to TContestSession.ConsumeFrames. This makes audible playback, including
intentional underrun silence, the only source of canonical session time without
allowing the callback to touch contest state.

### 8.3 Start and stop lifecycle

Start:

1. Validate settings.
2. Create/reset engine.
3. Preallocate ring and recorder resources.
4. Open PortAudio.
5. Start producer and prefill a minimum number of blocks.
6. Start PortAudio stream.
7. Publish SessionStarted.

Normal stop:

1. Stop accepting user contest commands.
2. Tell the engine to finish at a block boundary.
3. Stop or drain the producer according to session semantics.
4. Stop the PortAudio stream.
5. Join the producer.
6. Finalize the recorder.
7. Close PortAudio.
8. Publish final log, score, and SessionStopped.

Abort or application shutdown:

1. Set the stop flag.
2. Abort the PortAudio stream.
3. Wake and join the producer.
4. Finalize or discard partial recording safely.
5. Close native handles.

Every successful PortAudio initialization must have a matching termination.
Every opened stream must be closed exactly once.

## 9. Simulation Refactoring

### 9.1 Settings

Replace mutable global variables in Ini.pas with a typed TContestSettings
record or class. Separate:

- User station settings.
- Band-condition settings.
- Session settings.
- Audio settings.
- Persistent UI preferences.

The engine receives a validated settings snapshot at session start. Runtime
changes use commands and engine methods rather than shared globals.

### 9.2 Randomness

Introduce an application-owned random source with explicit seed support.

Production sessions may seed from the operating system or current time. Tests
must use fixed seeds. All random behavior in RndFunc, stations, operators,
noise, QRM, QRN, QSB, and call selection must use the injected source.

Do not change statistical algorithms during the initial extraction.

### 9.3 Logging and scoring

Move TQso and score calculation into model units. The model should expose:

- Add QSO.
- Apply simulated remote-log verification.
- Detect duplicates.
- Calculate raw and verified score.
- Calculate rate buckets.
- Produce formatted rows.
- Produce WPX score strings and HST result records.

The UI owns text styling, list controls, histograms, and dialogs.

### 9.4 Call list

Retain compatibility with Master.dta after documenting and testing its binary
format. Replace pointer sorting with length-aware parsing into Pascal strings.

Search in this order:

1. Explicit command-line or settings path.
2. XDG user data directory.
3. Current directory for development convenience.
4. Installed system data directory.

The fallback call remains available when no valid list is found, but the UI
must show a non-fatal warning.

Verify the provenance and redistribution terms of the imported Master.dta
before release.

Current implementation: TCallList safely validates and reads the legacy index
and NUL-delimited callsign payload into sorted, deduplicated Pascal strings. It
also reads Super Check Partial's line-based MASTER.SCP format, and
make update-call-list downloads the current contest list into the user's XDG
data directory with basic format/count validation before atomic replacement.
A versioned development snapshot is also kept at data/MASTER.SCP for offline
source checkouts; the user-owned XDG copy takes precedence. The native
single-session preview selects a caller from this list and sends its callsign;
the full caller state machine remains the next step.

## 10. User Interface

### 10.1 Layout

Use the Linux fork's LFM conversion as a visual and control mapping reference,
then normalize anchors and sizing for GTK3 rather than preserving fixed
96-DPI pixel geometry.

The UI must remain compact and contest-oriented:

- Call, RST, and number entry fields.
- F1 through F8 message buttons.
- Run mode and stop controls.
- Contest clock and pile-up status.
- Station and band-condition settings.
- Log display.
- Raw and verified score display.
- Rate histogram.
- Score/result dialogs.

### 10.2 Keyboard behavior

Preserve all documented bindings, including:

- F1 through F8.
- Backslash for CQ.
- Escape to abort sending.
- Alt-W, Ctrl-W, and F11 to wipe.
- Modified Enter to save.
- Space for field completion/advance.
- Semicolon and Insert for call plus number.
- Plus, period, comma, and left bracket for TU plus save.
- Enter Sends Messages behavior.
- Up and Down for RIT.
- Modified Up and Down for bandwidth.
- Page Up, Page Down, and modified F9/F10 for WPM.

Use event-provided Lazarus shift state instead of polling GetKeyState.
Test behavior under GTK3 on Wayland and X11 because desktop environments may
reserve some modified key combinations.

### 10.3 Accessibility

The menu-driven alternatives added for blind operators are product behavior,
not optional polish. Every contest function must remain reachable without a
mouse. Controls need meaningful accessible names, labels, focus order, and
visible focus indication.

Do not communicate log errors or overload state using color alone.

## 11. Filesystem and Desktop Integration

Add:

- A reverse-DNS application ID, proposed org.ve3nea.MorseRunner.
- A desktop entry.
- AppStream metadata.
- PNG icons at standard sizes and a scalable SVG if a suitable source asset is
  available.
- Installed documentation.
- A command-line version option.
- A command-line data path override useful for testing.

Use LCL OpenURL/OpenDocument facilities or a small Linux platform service for
URLs and files. Do not invoke a shell with unquoted user data.

Saved files must be created with ordinary user permissions. Use atomic
replace-write behavior for configuration where practical.

## 12. Proposed Repository Layout

The migration may proceed in place, but the intended end state is:

    src/
      app/
        morserunner.lpr
        appcontroller.pas
      core/
        contestengine.pas
        contestsettings.pas
        station.pas
        dxstation.pas
        dxoperator.pas
        qso_log.pas
        scoring.pas
        randomsource.pas
      dsp/
        soundtypes.pas
        morsekey.pas
        filters.pas
        mixers.pas
        volumecontrol.pas
      audio/
        audiooutput.pas
        portaudio_output.pas
        pcm_ring.pas
        wav_recorder.pas
        portaudio.pas
      platform/
        xdgpaths.pas
        desktopservices.pas
      ui/
        mainform.pas
        mainform.lfm
        scoredialog.pas
        scoredialog.lfm
    data/
      Master.dta
    packaging/
      debian/
      appstream/
      desktop/
      icons/
    tests/
      unit/
      integration/
      fixtures/
    tools/
    Makefile
    MorseRunner.lpi

Perform moves in small commits after tests exist so that behavioral changes are
not hidden inside mechanical renames.

## 13. Build and Toolchain

### 13.1 Reproducible environment

Provide a container definition pinned to:

- FPC 3.2.2.
- Lazarus 4.8.
- GTK3 development libraries.
- PortAudio 19 development files.

The current development host has /usr/bin/fpc linked to a PoshC2 helper rather
than the Free Pascal compiler. The working tree therefore supports an
unprivileged project-local toolchain in .toolchain/ (excluded from version
control): FPC 3.2.2 and a Lazarus 4.8 source build with GTK3 LCL. This permits
development where a system package install is unavailable. CI and release
builds must still use a pinned, clean environment rather than this local cache.

### 13.2 Commands

The current wrapper targets are:

    make core-test
    make lazarus-core-test
    make linux-app
    make audio-smoke-test
    make clean

The first two compile and run the headless settings, QSO-log, contest-session,
PCM-ring, legacy PCM-producer, Morse-keyer, Morse-tone-renderer, Morse-audio
producer, Morse-message-template, and PortAudio callback tests. The Linux
target compiles the GTK3 executable to build/bin/morserunner-linux. When the
local toolchain exists, the Makefile selects it automatically.

The underlying application build uses:

    lazbuild --ws=gtk3 MorseRunnerLinux.lpi

CI and packaging must use the same wrapper commands as developers.
audio-smoke-test is deliberately excluded from ordinary CI because it opens the
default output device; it emits only silence and verifies stream startup,
callback sizing, and reported playback progress on a configured desktop.

### 13.3 Compiler policy

Enable useful range, overflow, I/O, and assertions in debug/test builds. Treat
warnings that indicate pointer truncation, uninitialized state, implicit string
conversion, or unreachable code as release blockers.

Release builds may disable expensive checks only after the checked test suite
passes.

## 14. Test Strategy

### 14.1 Unit tests

Add tests for:

- Morse table encoding.
- Keyer envelope duration, padding, and ramp shape.
- Seconds-to-block and block-to-seconds conversion.
- Random distribution helpers with fixed seeds and statistical tolerances.
- Mixer frequency and phase continuity.
- Moving-average filters.
- AGC attack, hold, release, and overload behavior.
- QSB gain continuity.
- Station state transitions.
- Operator reply state machine.
- Callsign parsing and WPX prefix calculation.
- Duplicate, NIL, RST, and number error detection.
- Raw and verified scores.
- Call-list parsing and rejection of malformed data.
- WAV header and sample encoding.
- XDG path resolution.

### 14.2 Golden compatibility tests

Use fixed settings, call lists, commands, and seeds to run known sessions.
Compare:

- Ordered engine events.
- QSO entries.
- Score changes.
- Station counts and transitions.
- Total rendered frame counts.
- PCM length, peak, RMS, and selected spectral measurements.

Exact PCM hashes may be used on a pinned x86-64 CI image, but portable tests
should use numeric tolerances.

### 14.3 Audio tests

Test the ring buffer without a sound device.

Add an integration test with a null or virtual audio sink when available.
Verify:

- Callback never reads unpublished memory.
- Underruns produce silence and do not corrupt state.
- Ring wraparound.
- Stop during an empty or full ring.
- Repeated start/stop.
- Audio device open failure.
- Stream callback error.
- Recorder failure.
- Application shutdown while a session is active.

### 14.4 UI tests

Automate controller-level keyboard mapping where practical. Manually test:

- Wayland and X11.
- GNOME and KDE or equivalent GTK integration.
- 100, 150, and 200 percent scaling.
- Keyboard-only operation.
- Screen-reader labels.
- All four run modes.
- Score dialogs and result files.

### 14.5 Soak and performance tests

Run at least:

- A 60-minute session with recording disabled.
- A 60-minute session with recording enabled.
- One hundred start/stop cycles.
- Rapid command input while audio is active.

Capture CPU usage, resident memory, producer starvation, callback underruns,
render-ahead depth, and contest/audio clock divergence. Performance thresholds
should be finalized from measurements on a documented reference machine.

## 15. Continuous Integration

Required pull-request jobs:

1. Formatting and repository checks.
2. GTK3 compile in the pinned toolchain.
3. Unit tests with runtime checks enabled.
4. Headless deterministic integration tests.
5. Debian package build.

Required scheduled or release jobs:

- 60-minute headless soak.
- Audio null-sink integration where CI supports it.
- x86-64 release build.
- AArch64 compile and tests once the first x86-64 alpha is stable.

No Windows job is required.

## 16. Packaging and Distribution

### 16.1 First release

Produce:

- Debian source and binary packages.
- A generic versioned Linux tarball or AppImage.
- Checksums and source links satisfying MPL requirements.

Coordinate Debian changes with the Debian Hamradio Maintainers. Upstream the
current Debian XDG, Master.dta path, desktop, and metadata fixes so the Debian
package can reduce its downstream patch set.

### 16.2 Later packaging

Flatpak is deferred until PortAudio operation and audio permissions are
validated in its sandbox. A direct PulseAudio or PipeWire backend may be useful
for Flatpak, but is not required for the first native release.

## 17. Migration Phases and Exit Gates

### Phase 0: Establish history and build

Work:

- Fresh clone of the target repository.
- Create linux-native branch.
- Add the existing Linux fork as a Git remote.
- Merge or selectively replay the Lazarus conversion with attribution.
- Apply and attribute Debian fixes.
- Preserve LICENSE and source notices.
- Add pinned build container and wrapper Makefile.

Exit gate:

- A clean container produces a native GTK3 executable.
- No functionality claim is made yet.

Estimated effort: 3 to 5 days.

### Phase 1: Behavior lock

Work:

- Seedable randomness.
- Initial FPCUnit project.
- Tests for Morse generation, timing, scoring, operators, and DSP.
- Fixed-seed headless session harness.
- Compatibility fixtures.

Exit gate:

- Core behavior can be run and checked without a form or audio device.

Estimated effort: 1 week.

### Phase 2: Core extraction

Work:

- Typed settings.
- QSO and score models.
- Engine events and snapshots.
- Remove MainForm dependencies from Contest, Log, and Ini.
- Remove remaining Windows dependencies from core/DSP units.

Exit gate:

- Core and DSP units compile in an LCL-free test executable.
- No core unit uses Main or Forms.

Estimated effort: 1 to 2 weeks.

### Phase 3: Production audio path

Work:

- Fixed PCM ring.
- Producer thread.
- PortAudio lifecycle implementation.
- Frame-consumption clock.
- WAV recorder.
- Audio error reporting and statistics.

Exit gate:

- Stable native audio through a 60-minute test.
- No GTK access from producer or callback threads.
- No allocation or blocking in the callback.

Estimated effort: 1 to 2 weeks.

### Phase 4: GTK3 UI

Work:

- Responsive GTK3 form layouts.
- Controller binding.
- Complete keyboard behavior.
- Log, score, and histogram presentation.
- Accessibility pass.

Exit gate:

- All original workflows function under Wayland and X11.

Estimated effort: 1 to 2 weeks.

### Phase 5: Linux integration and packaging

Work:

- XDG persistence and migration.
- Desktop entry, AppStream, icons, and documentation.
- Debian and generic package.
- CI release jobs.

Exit gate:

- Install, upgrade, launch, record, persist, and uninstall tests pass.

Estimated effort: 1 week.

### Phase 6: Release validation

Work:

- Full mode matrix.
- Long audio and recording soak tests.
- x86-64 release candidate.
- AArch64 compile/test qualification.
- Documentation and known-issues review.

Exit gate:

- All release acceptance criteria are satisfied.

Estimated effort: 1 week.

Total expected effort: 6 to 9 focused engineer-weeks. A native alpha should be
possible after approximately 2 to 3 weeks.

## 18. Release Acceptance Criteria

The first stable native Linux release is complete when:

1. It is a native ELF executable with no Wine, WinMM, Windows DLL, or Windows
   runtime dependency.
2. Pile-Up, Single Calls, WPX, and HST modes pass scripted and manual tests.
3. Every documented keyboard command works under Wayland and X11, subject to
   documented desktop-reserved shortcuts.
4. Displayed contest time remains within one audio block plus one UI refresh of
   frames actually consumed.
5. A 60-minute session has no deadlock, runaway clock, buffer corruption, or
   unhandled audio error.
6. Default settings produce no underruns on the documented reference system.
7. One hundred start/stop cycles complete without a hang or growing native
   resource count.
8. WAV recordings have valid headers, correct duration, and playable PCM.
9. Settings, scores, and results persist in XDG locations across upgrades.
10. The application behaves correctly at 100, 150, and 200 percent scaling.
11. The x86-64 clean build and full tests pass.
12. AArch64 at least compiles and passes headless tests.
13. No known pointer-width truncation remains.
14. No LCL object is accessed outside the GTK main thread.
15. The audio callback performs no allocation, blocking operation, disk I/O,
    logging, or application logic.
16. Source, notices, dependency licenses, and data provenance satisfy MPL and
    distribution requirements.

## 19. Risks and Mitigations

### Audio fidelity regression

Risk: Refactoring timing or buffering changes the characteristic sound.

Mitigation: Keep the original sample rate and DSP equations, add fixed-seed
golden measurements before modifying the algorithms, and review reference WAV
output.

### Timing drift or runaway simulation

Risk: Producer speed becomes the contest clock.

Mitigation: Bind the canonical clock to frames committed and consumed through a
bounded ring. Record clock divergence in soak tests.

### Thread races

Risk: The existing port's shared buffer design corrupts data or touches GTK
from the wrong thread.

Mitigation: Exclusive engine ownership, immutable snapshots, a fixed SPSC PCM
ring, explicit shutdown joins, and callback restrictions.

### GTK3 widgetset regressions

Risk: Layout or keyboard behavior differs between Wayland, X11, GNOME, and KDE.

Mitigation: Use standard LCL controls, responsive anchors, minimal LCLIntf use,
and an explicit desktop test matrix. The Lazarus 4.8 GTK3 smoke binary currently
starts under Xvfb but emits GTK critical messages inside the widgetset. Treat
GTK3 as a prototype-only choice until the same smoke test is clean on a newer
Lazarus build and on real Wayland/X11 desktops; reassess Qt6 if that does not
close promptly.

### Old Pascal assumptions on 64-bit systems

Risk: Pointer truncation or dynamic-array hacks fail on x86-64 or AArch64.

Mitigation: Remove pointer-to-Integer casts, use PtrInt/PtrUInt only at defined
interop boundaries, and run checked builds plus AArch64 CI.

### Call-list provenance

Risk: Master.dta is useful but its format or redistribution history is not
documented in the original snapshot.

Mitigation: Trace provenance through the Linux fork and Debian copyright
records, document it, test the parser, and provide a user-supplied-data path.

### Toolchain age

Risk: FPC 3.2.2 is the current stable compiler but is old relative to Lazarus
development.

Mitigation: Pin and test the exact compiler/toolkit pair in a container. Avoid
compiler-specific undefined behavior and keep a scheduled build against a
validated development snapshot separate from release builds.

## 20. Open Questions

These do not block Phase 0 or Phase 1:

1. Should the generic release be AppImage, a relocatable tarball, or both?
2. Is AArch64 required for the first stable release or acceptable immediately
   afterward?
3. Should recordings be stored automatically in the XDG data directory or
   selected through a save dialog?
4. Should the legacy audio-buffer-size setting remain user visible, or be
   replaced by named latency presets?
5. Is exact compatibility with the historical online WPX score endpoint still
   useful, given its age and HTTP URL?
6. Is a native PipeWire backend desirable after the PortAudio release is
   stable?
7. Can the Master.dta provenance be documented strongly enough to keep it in
   upstream release archives?

## 21. Recommended First Implementation Slice

The first implementation change should not start with visual polish. It should
produce a narrow vertical slice:

1. Clean Git branch with imported Lazarus project and attribution.
2. Pinned GTK3 build environment.
3. Headless TContestEngine with a fixed seed.
4. One test that renders a known CQ audio sequence.
5. A production-shaped PCM ring and PortAudio callback.
6. A minimal GTK3 window that starts and stops the session and displays the
   sample-clock time.

This slice proves the highest-risk boundaries: compiler compatibility, engine
extraction, audio pacing, thread ownership, and GTK3 event delivery.

## 22. Initial Implementation Record

The first porting slice introduced:

- A UI-independent ContestSettings unit with typed contest, band, and audio
  settings plus legacy-compatible normalization bounds.
- A UI-independent TContestSettingsStore that persists the typed settings in
  XDG_CONFIG_HOME/morserunner/config.ini (or ~/.config/morserunner/config.ini),
  imports a discovered MorseRunner.ini only on first native launch, translates
  the legacy pitch/bandwidth indexes and buffer-size exponent, and never
  rewrites the old configuration file. The GTK startup loads this store and
  saves its normalized settings during orderly shutdown.
- Direct and Lazarus tests cover native-settings round trips, normalization,
  legacy INI conversion, persistence of the import, and native-file precedence
  after import.
- A UI-independent TCallList that reads validated legacy Master.dta call lists
  into owned strings, removes pointer-width assumptions, deduplicates entries,
  and follows the XDG-first data search path. Direct and Lazarus fixtures cover
  valid indexed data, duplicate removal, safe selection, and malformed-input
  rejection.
- A ContestTiming unit that makes the sample/frame clock explicit without
  depending on Ini, Main, or any LCL unit.
- A standalone headless test executable for defaults, settings normalization,
  callsign validation, legacy block timing, and sample-clock session duration.
- A Lazarus test project plus a Makefile and Docker build definition for a
  reproducible FPC/Lazarus GTK3 environment.
- A UI-independent QsoLog unit that preserves the legacy prefix extraction,
  duplicate detection, QSO error precedence, contest multipliers, and HST
  element-score calculations. Its data model is deliberately compatible with
  the legacy Log.TQso record so the form-facing unit can later become a thin
  presenter rather than reimplementing scoring rules.
- Separate tests for standard and HST score accounting, prefix edge cases, and
  the legacy error-priority order (NIL, duplicate, RST, serial number).
- A TContestSession core model that owns normalized settings, explicit
  sample-frame progress, start/stop state, end reasons, QSO submission, and
  mode-specific score selection. It establishes the audio-consumed frame count
  as the session time boundary; it has no LCL or audio-library dependency.
- A minimal Lazarus GTK3 executable that creates the first native Linux window
  and starts a default-device CQ preview through PortAudio. Its UI timer now
  polls and applies callback-reported playback frames; it no longer simulates
  session time from wall-clock milliseconds. It exposes persisted callsign,
  WPM, pitch, and duration controls before start, and an in-session text field
  that queues a placeholder-expanded Morse transmission after the current block
  sequence. Device opening remains an interactive hardware path that needs
  broader runtime validation.
- A project-local FPC 3.2.2 and Lazarus 4.8/GTK3 toolchain, used because the
  system fpc command is unrelated to Free Pascal and system-wide installation
  requires interactive sudo credentials.
- A TPcmSpscRing with preallocated signed-16-bit blocks, a logical capacity of
  two or more producer blocks, atomic slot publication, full-ring rejection,
  and callback-safe silence on underrun. Reset remains an explicit
  stopped-lifecycle operation.
- Direct and Lazarus test coverage for ring ordering, wraparound, capacity,
  reset, and underrun accounting.
- A UI-independent legacy PCM producer that preserves the original
  TAlSoundOut conversion rule exactly: round each renderer Single sample, then
  clamp it to the signed-16-bit range -32767..32767. It owns its preallocated
  conversion scratch block and commits only PCM blocks to the ring.
- Direct and Lazarus tests for clipping, rounding, block conversion/queueing,
  and invalid producer block sizes.
- A UI-independent Morse keyer derived from the legacy keyer/table code. It
  retains the legacy 11,025 Hz, 5 ms Blackman-Harris envelope default and
  block-padding calculation, while validating impossible timing parameters
  before rendering. It exposes encoded Morse and rendered Single blocks
  without global state, forms, Ini, or sound-device dependencies.
- Direct and Lazarus tests for case-insensitive CQ encoding, word spacing,
  a deterministic block-padded CQ envelope, and invalid timing rejection.
- A UI-independent CW tone renderer derived from the legacy real-carrier
  modulator. It preserves the legacy integer-cycle carrier quantization
  (600 Hz becomes 612.5 Hz at 11,025 Hz), maintains phase across producer
  blocks, and emits legacy-scale Single samples for the PCM producer.
- Direct and Lazarus tests for quantization, carrier samples, phase
  continuity, and invalid format parameters.
- A single-producer Morse audio bridge that stages a block-padded keyer
  envelope, renders carrier blocks only when the ring has capacity, converts
  them through the legacy PCM rule, and commits them to the PCM ring. Carrier
  phase remains continuous between serialized messages; message replacement is
  explicit rather than silently dropping pending samples.
- Direct and Lazarus tests prove back-pressure pauses/resumes production,
  producer-frame accounting, serialization, cancellation, and reset behavior.
- A UI-independent message-template expander derived from legacy station
  transmission text. It resolves <my>, <his>, and <#> placeholders without
  depending on global Ini, station objects, or UI controls; the native preview
  now sends the configured callsign in its CQ message.
- Direct and Lazarus tests cover mixed/repeated placeholders and invalid
  exchange values.
- A narrow PortAudio 19 declaration and output owner. It owns exactly one
  default mono signed-16-bit stream, pairs successful initialization with
  termination, and uses no legacy global sound object.
- The PortAudio callback reads only the preallocated PCM ring. It copies one
  exact configured block or writes silence on underrun; unexpected callback
  sizes are zero-filled, counted, and aborted without calling LCL, contest, or
  PortAudio control APIs.
- Direct and Lazarus tests link to the installed libportaudio, verify version
  metadata without initializing a device, and exercise the callback-to-ring
  transfer, played-frame accounting, controller/session handoff, and
  underrun/mismatched-size paths without opening audio.
- An opt-in default-device smoke test pre-fills silent PCM, opens a 11,025 Hz
  mono PortAudio stream, verifies playback progress and fixed callback sizing,
  then stops and closes the stream. It is not a CI requirement.

This is intentionally parallel to the Delphi/VCL application. The native
executable now replaces its own configuration boundary, but does not yet
replace the remaining legacy global settings in the historical VCL source,
Log.pas, or the old WinMM audio path. The next slice should connect
contest-station state and command handling to the preview producer, replace its
temporary CQ-loop sender with the real station/pile-up engine, and validate the
default-device start, stop, and error paths on real PipeWire and PulseAudio
desktops.

### Validation status (2026-08-10)

The local FPC 3.2.2 install compiled and ran all eleven headless test executables
through both direct FPC and Lazarus builds:

- settings/timing;
- XDG settings persistence and one-time legacy-INI import;
- QSO log/scoring;
- contest session lifecycle.
- PCM SPSC ring behavior.
- Legacy Single-to-PCM16 conversion and producer/ring handoff.
- Morse encoding and deterministic keyer-envelope rendering.
- Legacy-quantized CW carrier rendering and phase continuity.
- Keyer-to-carrier-to-PCM producer/ring handoff with bounded back-pressure.
- Legacy station-message placeholder expansion for native preview transmission.
- PortAudio callback frame accounting and controller-to-session clock handoff
  without a physical output device.

The GTK3 LCL application also compiles to a 64-bit ELF binary that links
libgtk-3, libgdk-3, and libportaudio. A three-second Xvfb launch smoke test
previously kept the application running, but emitted GTK critical messages from
Lazarus 4.8's GTK3 widgetset. The opt-in 11,025 Hz silent PortAudio smoke test
also passed against this host's PipeWire/PulseAudio default HDMI sink, including
callback sizing and shutdown. PortAudio emitted non-fatal ALSA/JACK backend
probe messages while enumerating alternatives. Docker remains unavailable to
this session because its daemon socket is not accessible.

## 23. References

- Original repository:
  https://github.com/VE3NEA/MorseRunner
- Target fork:
  https://github.com/garyPenhook/MorseRunner
- Existing Lazarus/PortAudio fork:
  https://github.com/fritzsche/MorseRunner
- Debian package tracker:
  https://tracker.debian.org/pkg/morserunner
- Debian source package:
  https://packages.debian.org/source/trixie-backports/morserunner
- Lazarus news and releases:
  https://www.lazarus-ide.org/index.php?page=news
- Lazarus Qt6 widgetset source:
  https://gitlab.com/freepascal.org/lazarus/lazarus/-/tree/main/lcl/interfaces/qt6
- Free Pascal downloads:
  https://docs.freepascal.org/download.html
- XDG Base Directory specification:
  https://specifications.freedesktop.org/basedir/
