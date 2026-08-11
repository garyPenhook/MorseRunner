# Morse Runner Linux code review

Review date: 2026-08-10

## Executive summary

The project builds and its extracted-core tests pass, but it is not ready for a
portable Linux release without further work. The most serious problems are in
the production PulseAudio bridge, release packaging, production-test coverage,
configuration validation, and GTK layout strategy.

This review found eight high-priority release blockers, eleven medium-priority
defects or engineering risks, and nine lower-priority cleanup items. The green
test result currently gives more confidence than it should: `make core-test`
tests the newer `src/core` and PortAudio seam, while `make linux-app`, the `.deb`,
and the AppImage ship the separate legacy engine in `native/engine` with a C
PulseAudio backend.

Severity meanings:

- **High:** fix before the next public release.
- **Medium:** fix soon; it can cause incorrect behavior, weakens reliability, or
  makes releases difficult to trust.
- **Low:** cleanup, diagnostics, portability, or maintainability debt.

## High-priority findings

### MR-001 — The production audio ring has C data races

**Evidence:** `native/engine/linux/VCL/AudioBackendPulse.c:45-55`, `:62-75`,
`:99-128`, `:141-199`, `:227-278`.

`gReadPos`, `gWritePos`, `gNeedsData`, `gRunning`, and `gVolume` are shared
between the Pascal/UI thread and the playback pthread. They are declared
`volatile`, but `volatile` is not thread synchronization in C. The ring also
publishes a new write position without a C acquire/release operation. The C
memory model therefore permits stale reads and reordering, and the program has
undefined behavior even though the single-producer/single-consumer algorithm
often appears to work on x86-64.

**Impact:** intermittent audio corruption, missed refill notifications, hangs,
or failures that change with compiler optimization or CPU architecture.

**Fix:** use C11 `_Atomic` indices/flags with explicit acquire/release ordering,
or protect all shared state with a mutex/condition variable. Add a stress test
and run it under ThreadSanitizer on a supported C harness.

### MR-002 — Playback-thread failure is silent and leaves the backend logically running

**Evidence:** `native/engine/linux/VCL/AudioBackendPulse.c:99-131` and
`native/engine/linux/VCL/SndOut.pas:139-168`.

When `pa_simple_write` fails, the playback thread prints one diagnostic and
returns. It does not clear `gRunning`, record an error state, or notify Pascal.
The UI timer continues asking for data and `PutData` can continue filling a ring
that no thread consumes.

**Impact:** audio dies while the contest UI continues as if it were healthy.
The normal launcher redirects the only useful error to a log file, making the
failure look like unexplained silence.

**Fix:** add an atomic backend state and last-error value, expose them to Pascal,
stop refill activity on failure, and show a clear UI error. Define restart and
cleanup behavior for a failed thread.

### MR-003 — The AppImage does not contain the libraries needed by the application

**Evidence:** `Makefile:238-257`. The built AppDir contains the application and
data files but no shared libraries. `ldd native/engine/MorseRunner` reports
GTK3, GDK, GLib, Cairo, Pango, HarfBuzz, PulseAudio, and many transitive host
libraries. The application itself requires `GLIBC_2.34`.

`appimagetool` packages the directory it receives; it does not automatically
deploy those dependencies. The current `appimage-test` invokes
`--appimage-help`, which is handled by the AppImage runtime before `AppRun` and
therefore does not launch Morse Runner at all.

**Impact:** the artifact described as portable will fail on distributions that
do not already provide compatible GTK3/PulseAudio libraries, and on systems
with an older glibc baseline.

**Fix:** build on an intentionally old supported base image, deploy non-base
libraries with `linuxdeploy` or an equivalent audited process, set and verify
runtime library search paths, and test the extracted application in clean
containers from every supported distribution generation. Keep a real headless
startup test in addition to the AppImage-runtime check.

### MR-004 — Passing tests do not exercise the code that is released

**Evidence:** `Makefile:70-110`, `:160-168`, and `:259-268`.

All 13 `core-test` programs target `src/core` and `src/linux/PortAudioOutput.pas`.
The production build instead compiles the separate `native/engine` tree and
`AudioBackendPulse.c`. The upstream tests under `native/engine/Test` are not
built or run by the Makefile or CI. There are no automated production contest,
PulseAudio, form-layout, configuration-corruption, or package-launch tests.

**Impact:** regressions in the shipped contest engine, audio backend, and GUI can
pass CI. This is directly relevant to the repeated GUI-overlap and audio issues.

**Fix:** either finish making the tested core the production implementation, or
add an FPC-compatible production-engine test target. At minimum cover contest
selection/scoring, INI boundary values, the PulseAudio state machine, callsign
import, WAV writing, and GTK startup/layout at multiple scale factors.

### MR-005 — A documented clean checkout cannot build with the documented commands

**Evidence:** `.gitignore:2`, `README.md:14-28`, and `Makefile:145-158`.

The README says the repository includes the required toolchain, but
`.toolchain/` is ignored. `make linux-app` unconditionally depends on a stamp
inside `.toolchain/lazarus-4.8` and its recipe explicitly rejects a missing
project-local Lazarus tree. A system `lazbuild` selected at `Makefile:15-20`
does not avoid that dependency. The CI workflow contains private knowledge of
how to clone and build Lazarus, but the user-facing build instructions do not.

**Impact:** a fresh source checkout fails before building, even when system FPC
and Lazarus are installed.

**Fix:** provide a bootstrap target/script that fetches a pinned Lazarus commit
and verifies it, or make the compatibility patch optional when a compatible
system Lazarus is used. Update the README and test a completely clean clone in
CI.

### MR-006 — Malformed INI values can index arrays outside their declared ranges

**Evidence:** `native/engine/linux/Main.pas:463-474`, `:2760-2771`, and
`native/engine/mac/Ini.pas:30-31`, `:94-219`.

The saved contest value is checked with `V > Length(ContestDefinitions)`. This
accepts both `V = Length(...)` (one past the last valid index) and negative
values, then casts and indexes with the result. The serial-number setting is
also cast to `TSerialNrTypes` and used as an array index before it is validated.

**Impact:** a manually edited, truncated, or corrupted settings file can crash
the application or access unrelated memory during startup.

**Fix:** validate integers against `Ord(Low(...))..Ord(High(...))` before every
enum cast or array access. Add corrupt-INI regression tests with `-Cr -Co -Ci`
runtime checks enabled.

### MR-007 — The production form uses fixed pixel geometry and keeps reproducing GTK overlap

**Evidence:** `native/engine/linux/Main.lfm:652-803`,
`native/engine/linux/Main.pas:685-868`, and `:1524-1547`.

The station controls (`Call`, `CW Speed`, `WPM`, `CW Pitch`, and their editors)
use absolute pixel coordinates and explicit font heights. Runtime code then
applies more pixel adjustments for particular GTK behavior. That approach
cannot reliably accommodate different themes, font metrics, DPI scaling,
translations, GTK versions, or accessibility fonts. The existing resize code
only repositions the right-side panels; it does not reflow the station fields.

**Impact:** labels and fields overlap on supported desktops even though they
look correct on the build machine. Repeated coordinate patches are fragile and
can regress a different desktop configuration.

**Fix:** rebuild the station section with layout containers (`TGridPanel`,
`TFlowPanel`, or aligned child panels), anchors, `AutoSize`, margins, and minimum
sizes. Remove per-widget font/pixel assumptions. Add screenshot or geometry
assertions for 100%, 125%, 150%, and 200% scale using at least two GTK themes.

### MR-008 — Package validation does not establish that either release artifact is installable and runnable

**Evidence:** `Makefile:226-257` and `.github/workflows/linux.yml:33-46`.

The Debian test only extracts files and checks their names; it does not ask APT
to resolve dependencies, install the package, run `lintian`, or launch the
program. The AppImage test does not enter `AppRun`. CI runs only on Ubuntu
24.04 and uploads whatever those shallow checks produce.

**Impact:** dependency errors, launcher errors, missing libraries, broken
desktop integration, and startup failures can all be published by a green CI
job.

**Fix:** install the `.deb` in a clean Debian/Ubuntu container, run package
policy checks, launch it under Xvfb with isolated XDG directories, and perform
the same application-level launch for the AppImage on several base images.

## Medium-priority findings

### MR-009 — `PutData` accepts a partial write as complete and discards the remainder

**Evidence:** `native/engine/linux/VCL/SndOut.pas:155-168` and
`native/engine/linux/VCL/AudioBackendPulse.c:221-244`.

The C API explicitly permits a short write, but Pascal returns success for any
positive count and has no offset/retry state. Any unwritten samples are lost.
Normal low-water behavior makes this uncommon, but the API contract is still
incorrect and becomes visible under pressure or after backend changes.

**Fix:** require an all-or-nothing ring write, or retain the unwritten tail and
retry it before requesting another block. Count buffers only after all frames
have been accepted.

### MR-010 — Audio entry points do not validate sizes and can overflow conversions

**Evidence:** `native/engine/linux/VCL/AudioBackendPulse.c:141-168` and
`:227-243`.

`sampleRate`, `bufFrames`, `numBufs`, `samples`, and `nFrames` are not validated.
Negative frame counts and overflowing products are converted to `size_t` or
`uint32_t`; zero/negative buffer sizes can also create an invalid playback loop.
Strict GCC diagnostics additionally flag signed conversions in these paths.

**Fix:** reject null pointers, nonpositive values, values above the fixed ring
limit, and every multiplication that cannot be represented. Use `size_t` for
byte counts after checked conversion.

### MR-011 — Installed launchers can select the wrong executable and suppress useful failures

**Evidence:** `scripts/morserunner-linux-launcher:10-29`.

The same script is used for both build-tree and installed launches. It always
prefers a calculated `SOURCE_ENGINE`; for a user-local install this is
`~/native/engine/MorseRunner`, so an unrelated or stale executable there wins
over `~/.local/lib/morserunner/MorseRunner`. The script also does not check that
the final engine exists, and normal mode redirects the resulting diagnostic to
the GTK log.

**Fix:** use distinct development and installed launchers, or resolve the mode
from an explicit install-time path. Validate the engine and print a concise
terminal error before redirecting GTK-only diagnostics.

### MR-012 — Custom serial-number ranges are off by one and validation accepts zero

**Evidence:** `native/engine/mac/Ini.pas:317-375`.

For a displayed range such as `01-99`, `Random(MaxVal - MinVal)` never returns
99. A one-value range calls `Random(0)`. Parsing accepts `0-99` even though
`IsValid` later rejects it, leaving validation and execution inconsistent.

**Fix:** sample `Random(MaxVal - MinVal + 1)`, explicitly handle the single-value
case, reject minima below one during parsing, and test both endpoints.

### MR-013 — Contest exchange methods misuse an `out` object parameter

**Evidence:** `native/engine/Contest.pas:55`, `native/engine/DxStn.pas:67-70`,
and compiler warnings in `NaQp.pas:433`, `CqWW.pas:278`, `CqWpx.pas:301`,
`ALLJA.pas:216`, and `ACAG.pas:217`.

`GetExchange` declares `station` as output-only but every implementation mutates
an already-created `TDxStation`, and several read `station.Operid` before any
assignment. This contradicts the parameter contract and depends on compiler
behavior. Those methods also ignore their explicit `id` parameter.

**Fix:** change the base and all overrides to `const`/normal object input or
`var` as appropriate, and consistently use the passed `id`.

### MR-014 — Invalid enum values are used as sentinels

**Evidence:** `native/engine/QrnStn.pas:35-37` and
`native/engine/Util/SSExchParser.pas:159-185`.

The code casts `-1` into enum types whose valid ranges start at zero. The build
emits range-check warnings, and enabling runtime range checks can turn these
paths into exceptions. An accidental use as an array index would be unsafe.

**Fix:** add explicit `none`/`invalid` enum members or store the sentinel in a
wider integer/nullable representation.

### MR-015 — Release builds ship debug information, absolute build paths, and weak hardening

**Evidence:** `native/engine/MorseRunner_linux.lpi:249-265`.

The current executable is 41,498,496 bytes, contains DWARF sections and paths
under `/home/gary/...`, and is not stripped. A stripped diagnostic copy is about
8.9 MB. `checksec` reports partial RELRO, no PIE, no stack canary, and no
fortification (NX is enabled).

**Fix:** define separate Debug and Release build modes. Strip or split debug
symbols for release artifacts, remove build-path leakage, and enable supported
PIE/RELRO/hardening options for both FPC and the C object.

### MR-016 — The build downloads and executes mutable, unverified tools and source

**Evidence:** `Makefile:240-244` and `.github/workflows/linux.yml:14-31`.

`appimagetool` is downloaded from the mutable `continuous` release and executed
without a checksum or signature. CI actions use floating major tags, and
Lazarus is cloned from the moving `lazarus_4_8` branch rather than a commit.

**Fix:** pin immutable commits/releases, verify SHA-256 values or signatures,
and record the toolchain inputs in release provenance/SBOM output.

### MR-017 — Package staging directories are reused and architecture variables are misleading

**Evidence:** `Makefile:31-41`, `:219-224`, and `:246-253`.

The Debian and AppImage roots are only created, never freshly initialized.
Removed files can survive from an earlier build and leak into a later package.
`DEB_ARCH` and `APPIMAGE_ARCH` are configurable, but the production binary is
always copied from `native/engine/lib/x86_64-linux/MorseRunner`.

**Fix:** create a new temporary staging root for every package, atomically move
the final artifact into place, and either implement real cross-architecture
paths or reject every architecture except amd64/x86_64.

### MR-018 — Debian metadata is incomplete and manually maintained

**Evidence:** `packaging/debian/control.in:1-10` and the resulting package.

The maintainer address is `maintainers@invalid`; dependencies are handwritten
instead of generated from the ELF (`dpkg-shlibdeps`/debhelper); there is no
`/usr/share/doc/morserunner-linux/copyright`, changelog, or packaged license/
source-availability notice. The AppImage likewise contains no license file.

**Fix:** use a normal Debian source-package/debhelper layout, generate shlib
dependencies, provide real maintainer metadata and copyright/license files, and
run `lintian`. Confirm the distribution rights and attribution for bundled data
files as part of release compliance.

### MR-019 — Settings and user-list updates are not crash-safe

**Evidence:** `src/core/SettingsStore.pas:233-284`,
`native/engine/CallLst.pas:77-125`, and `native/engine/linux/Main.pas:584-660`.

Configuration and imported call lists are written directly to their final
paths. A crash, full disk, or concurrent instance can leave a truncated file.
There is no lock or last-known-good recovery. Production and preview code also
use different XDG locations and filename casing.

**Fix:** write a same-directory temporary file, flush and close it, then rename
atomically. Preserve a recoverable backup where useful, lock multi-instance
writes, and establish one documented path/casing convention.

## Low-priority findings

### MR-020 — The preview UI swallows start errors and leaves other audio errors unhandled

**Evidence:** `src/linux/LinuxMainForm.pas:257-305`.

The start handler catches every exception without showing its message. Stop and
timer handlers do not catch device errors at all. This is the experimental
preview, not the released GUI, but it makes that migration path hard to debug.

**Fix:** show actionable errors, preserve technical details in the diagnostic
log, and put the controller into a known stopped state after every failure.

### MR-021 — Preview reconfiguration is not exception-safe

**Evidence:** `src/linux/LinuxAudioSessionController.pas:180-203`.

`Configure` frees the live output, producer, and ring before constructing their
replacements. If allocation or construction fails, fields still refer to freed
objects and later cleanup can double-free them.

**Fix:** construct replacements in local variables first, then swap them into
the object only after all construction succeeds.

### MR-022 — Several numeric APIs lack defensive edge handling

**Evidence:** `src/core/LegacyPcmProducer.pas:37-43`,
`src/core/PcmRing.pas:46-63`, `:149-159`, and
`native/engine/mac/VCL/WavFile.pas:337-414`.

- `Round(Sample)` occurs before clamping, so NaN, infinity, or very large
  `Single` values can fault or overflow.
- Ring allocation arithmetic has no upper-bound/overflow checks.
- The pointer form of `ReadOrSilence` silently returns for a bad size instead of
  clearing or reporting the output.
- WAV loops use unsigned `0 to Count - 1`; a zero count underflows the upper
  bound. WAV reading also accepts format tags/channel counts/bit depths it does
  not actually implement.

**Fix:** validate all public numeric inputs before arithmetic and add zero,
overflow, NaN/infinity, EOF, and malformed-WAV tests.

### MR-023 — Documentation and version identities disagree with the build

**Evidence:** `README.md:17-28`, `:52-66`, `Makefile:31`,
`Makefile:198-200`, and `native/engine/mac/Main.pas:26`.

The README says to run `./build/bin/morserunner`, but the build only creates
`build/bin/morserunner-linux`. Packaging defaults to version `1.6.0`, while the
application identifies itself as `1.85.3`; prior artifacts with multiple
versions remain together in `build/packages`. The toolchain statement is also
incorrect for a clean checkout.

**Fix:** define one release version source, generate application/package names
from it, create the documented launcher alias, and test every README command in
CI.

### MR-024 — Compiler warning debt hides new defects

**Evidence:** a production build emits 47 warnings, including incomplete record
initializers in `native/engine/mac/Ini.pas`, invalid enum sentinels, the `out`
parameter misuse, a lossy Unicode caption at `native/engine/linux/Main.pas:782`,
and numerous managed-result warnings.

Some managed-array warnings are false positives, but leaving the warning stream
uncurated makes meaningful warnings easy to miss.

**Fix:** initialize result arrays explicitly where needed, fully initialize
record constants, replace invalid sentinels, correct signatures/Unicode types,
and make CI fail on a reviewed warning baseline.

### MR-025 — The C backend has no public header and is not built with review-grade warnings

**Evidence:** `Makefile:163-165` and
`native/engine/linux/VCL/AudioBackendPulse.c:141-278`.

Exported functions have no prior prototypes, the source contains a multiline
`//` comment ending in a backslash, and the normal build enables only `-O2` and
`-fPIC`. A strict C17 compile reports prototype and signed-conversion warnings.

**Fix:** add a shared header consumed by C/Pascal bindings, compile with an
explicit standard and strict warnings, and promote relevant warnings to errors.

### MR-026 — XDG fallback and diagnostic logging are fragile

**Evidence:** `native/engine/linux/GetDataPath.pas:38-53` and
`scripts/morserunner-linux-launcher:26-29`.

If `HOME` is unset, production user data resolves under `/.local/share`; failure
to create it is ignored. The launcher falls back to the predictable shared
`/tmp/.local/state` path and appends forever to one unrotated log.

**Fix:** fail clearly when no safe user directory exists, reject unsafe/shared
fallbacks, create directories with private permissions, and rotate or cap the
diagnostic log.

### MR-027 — Build cleanup and package-test temporary files are incomplete

**Evidence:** `Makefile:227-236` and `:280-281`.

`deb-test` leaves every temporary extraction directory behind. `make clean`
removes only `build/`, leaving the compiled native binary, C object, generated
units, copied call list, and patch stamps in the submodule. This makes clean-build
claims difficult to trust.

**Fix:** add shell traps to remove test stages and provide separate safe targets
for generated artifacts versus applied source patches.

### MR-028 — The container target does not reproduce the production build

**Evidence:** `tools/Dockerfile:1-14` and `Makefile:273-278`.

The container installs PortAudio dependencies but not the GTK3/PulseAudio
production toolchain, and `container-test` only runs the extracted core tests.
It also bind-mounts the workspace while running as container root, which can
leave root-owned build artifacts.

**Fix:** make the image build/test the production binary and both packages, pin
the base image digest, and run with the host UID/GID or use an isolated output
volume.

## Verification performed

- `make core-test`: passed all 13 test executables.
- `make linux-app`: succeeded; emitted 47 warnings described above.
- Strict C17 GCC syntax/warning pass: completed with signed-conversion,
  prototype, and comment warnings.
- `cppcheck` on the PulseAudio C backend: no additional findings.
- `sh -n` on all project shell scripts: passed.
- ShellCheck-based project script review: only two SC1007 style warnings for
  the `CDPATH= cd ...` idiom.
- `desktop-file-validate`: passed.
- `xmllint` and `appstreamcli validate`: passed; AppStream reported missing
  developer information as a pedantic issue.
- `.deb` structure inspection: layout is present, but install/dependency policy
  was not tested because `lintian` is not installed.
- AppImage contents and dynamic dependencies inspected: no application shared
  libraries are bundled.
- AppImage application startup on this host under Xvfb: reached the event loop
  and was stopped after five seconds. This proves startup on the build host only,
  not portability.
- ELF review: NX enabled; partial RELRO; no PIE, canary, or fortification;
  unstripped DWARF and absolute build paths present.

## Recommended repair order

1. Replace the PulseAudio shared-state implementation with defined C
   synchronization and add explicit failure propagation.
2. Convert the station settings area to container-based GTK layout and add
   scale/theme regression coverage.
3. Decide which engine is authoritative, then make production code—not only the
   extracted preview core—the target of automated tests.
4. Repair clean-clone bootstrap and pin every downloaded build input.
5. Add strict INI validation and fix serial-range generation.
6. Rebuild AppImage deployment and package tests around clean containers.
7. Finish Debian metadata, release hardening, atomic persistence, and warning
   cleanup.

## Review limitations and repository state

The outer workspace currently has no `.git` directory, so commit history,
tracked-file status, and the exact published revision could not be verified
from this directory. `native/engine` is a Git repository at commit
`502ae60782156a2e99129766a9bd9c007a78812e` and is intentionally dirty from the
applied overlay patches and generated artifacts. Restore or re-clone the outer
repository metadata before making the next commit so future reviews can compare
changes and verify release provenance normally.

The review covered all first-party build, package, shell, extracted-core, Linux
UI/audio, and production integration surfaces. It did not attempt a line-by-line
reaudit of bundled third-party Lazarus, FPC, PCRE, or upstream platform-specific
Windows/macOS code that is not compiled into the Linux release.

## Remediation status — 2026-08-10

The following findings have been fixed in the current working tree and are
preserved as reviewed overlays for the native engine:

- **MR-001, MR-002, MR-009, MR-010, MR-025:** the production PulseAudio ring
  now uses C17 atomics, validates every public size, publishes complete blocks
  only, propagates playback failures to the UI, and builds with strict warnings
  from a shared C header.
- **MR-005, MR-011, MR-017, MR-023, MR-026, MR-027:** clean-checkout bootstrap,
  launch path resolution, supported-architecture checks, unified versioning,
  private bounded logs/XDG failure handling, and clean package test staging are
  in place.
- **MR-006, MR-012, MR-013, MR-014, MR-022:** corrupted enum settings are
  bounded before use; serial-number ranges include both endpoints; contest
  exchange parameters have the correct `var` contract; invalid sentinels are
  explicit enum values; and PCM/WAV numeric edge cases are guarded and tested.
- **MR-015:** installed and packaged executables are stripped release binaries.
- **MR-016:** Lazarus, GitHub actions, and AppImage tooling are pinned or
  checksum-verified; a changed mutable tool download fails closed.
- **MR-018:** the package includes an actual configured maintainer, changelog,
  MPL license, and copyright notice. The maintainer default is intentionally
  overrideable through `DEB_MAINTAINER`.
- **MR-019:** preview settings, production settings, and production SCP imports
  publish same-directory temporary files through atomic renames.
- **MR-020, MR-021:** the preview exposes audio-start failures and constructs
  replacement audio objects before swapping them into the live session.
- **MR-007:** the Station rail now reflows after GTK realization from actual
  label/control dimensions, expands its minimum window width as needed, and
  recomputes row geometry on resize. This replaces the overlapping fixed
  positions for Call, CW Speed, CW Pitch, RX Bandwidth, and monitor level.
- **MR-003, MR-008, MR-028:** linuxdeploy now deploys the AppImage dependency
  closure and both artifacts have real Xvfb application-start tests. The
  Debian-11 container targets glibc 2.31 and CI uses its production/package
  gates while retaining host UID/GID ownership.

The following are deliberate remaining limits, not release blockers hidden by
this remediation:

- Production contest and audio unit tests are still much thinner than the
  extracted-core suite (**MR-004**). Package startup tests protect the shipped
  path, but do not replace a dedicated engine test harness or a TSan audio test.
- The UI reflow is covered by a production compile and Xvfb startup test, not
  screenshot geometry assertions under multiple GTK themes/scales (**MR-007**).
- Debian shared-library dependencies remain conservatively declared as GTK3 and
  PulseAudio runtime dependencies; a full debhelper source package,
  `dpkg-shlibdeps`, and `lintian` integration remain future work (**MR-018**).
- Atomic replacement prevents truncation, but multi-instance locking and
  last-known-good backups are not yet implemented (**MR-019**).
- The container base is intentionally the named Debian 11 release rather than
  an image digest, so a scheduled digest-refresh policy should be added before
  a long-lived reproducible-build claim (**MR-016/MR-028**).
- The legacy engine still emits a reviewed 40-warning baseline from upstream
  code (**MR-024**); the unsafe enum/out-parameter warnings identified by this
  review have been removed, but broader warning cleanup remains.
