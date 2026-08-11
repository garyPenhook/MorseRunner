LOCAL_FPC := $(CURDIR)/.toolchain/fpc-3.2.2/bin/fpc
LOCAL_FPC_BIN_DIR := $(dir $(LOCAL_FPC))
LOCAL_LAZARUS_DIR := $(CURDIR)/.toolchain/lazarus-4.8
LOCAL_LAZBUILD := $(LOCAL_LAZARUS_DIR)/lazbuild
ifeq ($(wildcard $(LOCAL_FPC)),)
FPC ?= fpc
else
FPC ?= $(LOCAL_FPC)
endif
ifeq ($(wildcard $(LOCAL_FPC)),)
LCL_FPC := $(FPC)
else
LCL_FPC := $(abspath $(LOCAL_FPC))
endif
ifeq ($(wildcard $(LOCAL_LAZBUILD)),)
LAZBUILD ?= lazbuild
LAZBUILD_ARGS :=
else
LAZBUILD ?= $(LOCAL_LAZBUILD)
LAZBUILD_ARGS := --lazarusdir=$(LOCAL_LAZARUS_DIR) --ws=gtk3
endif
CONTAINER_RUNTIME ?= docker
CONTAINER_IMAGE ?= morserunner-linux-build
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/lib/morserunner
DATADIR ?= $(PREFIX)/share/morserunner
DESKTOPDIR ?= $(PREFIX)/share/applications
ICONDIR ?= $(PREFIX)/share/icons/hicolor/128x128/apps
METAINFODIR ?= $(PREFIX)/share/metainfo
PACKAGE_VERSION ?= 1.85.4
DEB_MAINTAINER ?= Gary Penhook <penhookcoder@gmail.com>
DEB_ARCH ?= $(shell dpkg --print-architecture)

BUILD_DIR := build
PACKAGE_DIR := $(BUILD_DIR)/packages
DEB_ROOT := $(PACKAGE_DIR)/deb/morserunner-linux_$(PACKAGE_VERSION)_$(DEB_ARCH)
DEB_OUTPUT := $(PACKAGE_DIR)/morserunner-linux_$(PACKAGE_VERSION)_$(DEB_ARCH).deb
APPIMAGE_ARCH ?= x86_64
APPIMAGE_TOOL := $(BUILD_DIR)/tools/appimagetool-$(APPIMAGE_ARCH).AppImage
APPIMAGE_TOOL_URL ?= https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$(APPIMAGE_ARCH).AppImage
# SHA-256 of the reviewed x86_64 tool input. A changed mutable upstream asset
# fails closed until its checksum is deliberately reviewed and updated.
APPIMAGE_TOOL_SHA256 ?= a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0
LINUXDEPLOY_TOOL := $(BUILD_DIR)/tools/linuxdeploy-$(APPIMAGE_ARCH).AppImage
LINUXDEPLOY_URL ?= https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$(APPIMAGE_ARCH).AppImage
LINUXDEPLOY_SHA256 ?= 421ca71d5c69ea97c6309276232990d43df1dcece0edfaa26bbf926ff96ed12e
LINUXDEPLOY ?= $(LINUXDEPLOY_TOOL)
APPIMAGE_ROOT := $(PACKAGE_DIR)/appimage/MorseRunner.AppDir
APPIMAGE_OUTPUT := $(PACKAGE_DIR)/MorseRunner-$(PACKAGE_VERSION)-$(APPIMAGE_ARCH).AppImage
# Direct FPC test builds and Lazarus projects use incompatible debug metadata.
# Keep their unit caches separate so either command may follow the other.
CORE_UNIT_DIR := $(BUILD_DIR)/fpc-units
CORE_BIN_DIR := $(BUILD_DIR)/bin
CORE_SOURCE_DIR := src/core
LINUX_SOURCE_DIR := src/linux
ENGINE_DIR := native/engine
ENGINE_AUDIO_SOURCE := $(ENGINE_DIR)/linux/VCL/AudioBackendPulse.c
ENGINE_AUDIO_HEADER := $(ENGINE_DIR)/linux/VCL/AudioBackendPulse.h
ENGINE_AUDIO_OBJECT := $(ENGINE_DIR)/linux/VCL/AudioBackendPulse.o
ENGINE_AUDIO_CFLAGS ?= -std=c17 -O2 -fPIC -Wall -Wextra -Wpedantic \
	-Wconversion -Wsign-conversion -Wshadow -Wstrict-prototypes \
	-Wmissing-prototypes -Wformat=2 -Wundef
ENGINE_BINARY := $(ENGINE_DIR)/MorseRunner
ENGINE_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-scp-patch-applied
ENGINE_UI_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-ui-patch-applied
ENGINE_HELP_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-help-patch-applied
ENGINE_IMPORT_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-import-patch-applied
ENGINE_AUDIO_LEVEL_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-audio-level-patch-applied
ENGINE_STATION_LAYOUT_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-station-layout-patch-applied
ENGINE_RUNTIME_FORM_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-runtime-form-patch-applied
ENGINE_AUDIO_SAFETY_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-audio-safety-patch-applied
ENGINE_CONFIG_VALIDATION_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-config-validation-patch-applied
ENGINE_XDG_PATH_SAFETY_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-xdg-path-safety-patch-applied
ENGINE_WAV_INPUT_SAFETY_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-wav-input-safety-patch-applied
ENGINE_EXCHANGE_API_SAFETY_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-exchange-api-safety-patch-applied
ENGINE_ENUM_SENTINEL_SAFETY_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-enum-sentinel-safety-patch-applied
ENGINE_RESPONSIVE_STATION_LAYOUT_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-responsive-station-layout-patch-applied
ENGINE_ATOMIC_CALL_LIST_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-atomic-call-list-patch-applied
ENGINE_ATOMIC_INI_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-atomic-ini-patch-applied
ENGINE_AUDIO_HEADER_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-audio-header-patch-applied
ENGINE_STATION_LAYOUT_HEIGHT_PATCH_STAMP := $(ENGINE_DIR)/.morserunner-station-layout-height-patch-applied
LAZARUS_GTK3_PATCH_STAMP := $(LOCAL_LAZARUS_DIR)/.morserunner-gtk3-patch-applied
LAZARUS_GTK3_BUILD_STAMP := $(LOCAL_LAZARUS_DIR)/.morserunner-gtk3-rebuilt
ENGINE_RUNTIME_DATA := ARRLDXCW_USDX.txt CQWWCW.txt CWOPS.LIST DXCC.LIST \
	FDGOTA.txt IARU_HF.txt JARL_ACAG.TXT JARL_ALLJA.TXT K1USNSST.txt \
	MASTER.DTA MASTER.SCP NAQPCW.txt Readme.txt SSCW.txt

.PHONY: bootstrap-toolchain check-toolchain check-native-engine check-package-arch check-appimage-tools lcl-gtk3 core-test lazarus-core-test linux-app install deb deb-test appimage appimage-test preview-app audio-smoke-test update-call-list container-build container-test container-release clean

bootstrap-toolchain:
	sh scripts/bootstrap-toolchain.sh .toolchain

check-toolchain:
	FPC="$(FPC)" sh tools/check-fpc.sh

core-test: check-toolchain
	mkdir -p $(CORE_UNIT_DIR) $(CORE_BIN_DIR)
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/core-settings-tests tests/CoreSettingsTests.lpr
	$(CORE_BIN_DIR)/core-settings-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/settings-store-tests tests/SettingsStoreTests.lpr
	$(CORE_BIN_DIR)/settings-store-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/call-list-tests tests/CallListTests.lpr
	$(CORE_BIN_DIR)/call-list-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/qso-log-tests tests/QsoLogTests.lpr
	$(CORE_BIN_DIR)/qso-log-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/contest-session-tests tests/ContestSessionTests.lpr
	$(CORE_BIN_DIR)/contest-session-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/pcm-ring-tests tests/PcmRingTests.lpr
	$(CORE_BIN_DIR)/pcm-ring-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/legacy-pcm-producer-tests tests/LegacyPcmProducerTests.lpr
	$(CORE_BIN_DIR)/legacy-pcm-producer-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/morse-keyer-tests tests/MorseKeyerTests.lpr
	$(CORE_BIN_DIR)/morse-keyer-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/morse-tone-renderer-tests tests/MorseToneRendererTests.lpr
	$(CORE_BIN_DIR)/morse-tone-renderer-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/morse-audio-producer-tests tests/MorseAudioProducerTests.lpr
	$(CORE_BIN_DIR)/morse-audio-producer-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/morse-message-template-tests tests/MorseMessageTemplateTests.lpr
	$(CORE_BIN_DIR)/morse-message-template-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/single-caller-practice-tests tests/SingleCallerPracticeTests.lpr
	$(CORE_BIN_DIR)/single-caller-practice-tests
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -Fu$(LINUX_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/portaudio-output-tests tests/PortAudioOutputTests.lpr
	$(CORE_BIN_DIR)/portaudio-output-tests

lazarus-core-test: check-toolchain
	mkdir -p $(CORE_UNIT_DIR) $(CORE_BIN_DIR)
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/CoreSettingsTests.lpi
	$(CORE_BIN_DIR)/core-settings-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/SettingsStoreTests.lpi
	$(CORE_BIN_DIR)/settings-store-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/CallListTests.lpi
	$(CORE_BIN_DIR)/call-list-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/QsoLogTests.lpi
	$(CORE_BIN_DIR)/qso-log-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/ContestSessionTests.lpi
	$(CORE_BIN_DIR)/contest-session-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/PcmRingTests.lpi
	$(CORE_BIN_DIR)/pcm-ring-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/LegacyPcmProducerTests.lpi
	$(CORE_BIN_DIR)/legacy-pcm-producer-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/MorseKeyerTests.lpi
	$(CORE_BIN_DIR)/morse-keyer-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/MorseToneRendererTests.lpi
	$(CORE_BIN_DIR)/morse-tone-renderer-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/MorseAudioProducerTests.lpi
	$(CORE_BIN_DIR)/morse-audio-producer-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/MorseMessageTemplateTests.lpi
	$(CORE_BIN_DIR)/morse-message-template-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/SingleCallerPracticeTests.lpi
	$(CORE_BIN_DIR)/single-caller-practice-tests
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/PortAudioOutputTests.lpi
	$(CORE_BIN_DIR)/portaudio-output-tests

check-native-engine:
	@test -f $(ENGINE_DIR)/MorseRunner_linux.lpi || \
		(echo "Native engine submodule is missing; run: git submodule update --init --recursive" >&2; exit 1)

check-package-arch:
	@test "$(DEB_ARCH)" = amd64 || \
		(echo "Only amd64 Debian packages are supported; got $(DEB_ARCH)." >&2; exit 1)
	@test "$(APPIMAGE_ARCH)" = x86_64 || \
		(echo "Only x86_64 AppImages are supported; got $(APPIMAGE_ARCH)." >&2; exit 1)

check-appimage-tools: $(LINUXDEPLOY_TOOL)
	@test -x "$(LINUXDEPLOY)" || \
		(echo "A reviewed linuxdeploy executable is required to bundle AppImage dependencies." >&2; exit 1)

ifeq ($(wildcard $(LOCAL_LAZBUILD)),)
# System Lazarus builds are supported for the portable-container target. The
# project-local tree below is only needed for the reviewed GTK3 compatibility
# patch used by normal developer and release builds.
lcl-gtk3:
	@command -v "$(LAZBUILD)" >/dev/null || \
		(echo "lazbuild is required; run: make bootstrap-toolchain" >&2; exit 1)
else
lcl-gtk3: $(LAZARUS_GTK3_BUILD_STAMP)
endif

# Lazarus 4.8's GTK3 interface touches internal combo popup gadgets as though
# they were normal widgets. Apply the reviewed compatibility patch before
# building the production app so current GTK3 desktops start cleanly.
$(LAZARUS_GTK3_PATCH_STAMP): patches/lazarus-gtk3-runtime-cleanup.patch
	@test -x $(LOCAL_LAZBUILD) || \
		(echo "The patched GTK3 build requires the project-local Lazarus source at $(LOCAL_LAZARUS_DIR)." >&2; exit 1)
	cd $(LOCAL_LAZARUS_DIR) && \
		if patch --dry-run --reverse -p1 < ../../patches/lazarus-gtk3-runtime-cleanup.patch >/dev/null 2>&1; then \
			echo "GTK3 compatibility patch is already applied"; \
		else \
			patch --forward --batch -p1 < ../../patches/lazarus-gtk3-runtime-cleanup.patch; \
		fi
	touch $@

$(LAZARUS_GTK3_BUILD_STAMP): $(LAZARUS_GTK3_PATCH_STAMP)
	$(MAKE) -C $(LOCAL_LAZARUS_DIR)/lcl cleanintf intf LCL_PLATFORM=gtk3 FPC="$(LCL_FPC)"
	touch $@

# The production Linux target is the full original Morse Runner engine and UI.
# Its reviewed Linux fixes are pinned in the project-owned engine submodule.
# Historical overlays remain in patches/ for provenance, but are not replayed:
# their former dry-run detection could mark a patch as applied without changing
# a fresh checkout.
linux-app: check-toolchain check-native-engine lcl-gtk3 $(CORE_BIN_DIR)/morserunner-linux
	cp data/MASTER.SCP $(ENGINE_DIR)/MASTER.SCP
	$(CC) $(ENGINE_AUDIO_CFLAGS) -c $(ENGINE_AUDIO_SOURCE) -o $(ENGINE_AUDIO_OBJECT) \
		$$(pkg-config --cflags libpulse-simple)
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) --build-all $(ENGINE_DIR)/MorseRunner_linux.lpi
	# The shipped executable is a release artifact: strip DWARF and absolute
	# build paths while retaining the unmodified compiler output under lib/ for
	# local debugging.
	install -s -m 755 $(ENGINE_DIR)/lib/x86_64-linux/MorseRunner $(ENGINE_BINARY).new
	mv -f $(ENGINE_BINARY).new $(ENGINE_BINARY)

$(ENGINE_PATCH_STAMP): patches/engine-load-master-scp.patch
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_UI_PATCH_STAMP): patches/engine-linux-ui-polish.patch
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_HELP_PATCH_STAMP): patches/engine-linux-help.patch $(ENGINE_UI_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_IMPORT_PATCH_STAMP): patches/engine-call-list-import.patch $(ENGINE_HELP_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_AUDIO_LEVEL_PATCH_STAMP): patches/engine-clean-output-level.patch $(ENGINE_IMPORT_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_STATION_LAYOUT_PATCH_STAMP): patches/engine-station-control-layout.patch $(ENGINE_AUDIO_LEVEL_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_RUNTIME_FORM_PATCH_STAMP): patches/engine-runtime-form-layout.patch $(ENGINE_STATION_LAYOUT_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_AUDIO_SAFETY_PATCH_STAMP): patches/engine-audio-backend-safety.patch $(ENGINE_RUNTIME_FORM_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_CONFIG_VALIDATION_PATCH_STAMP): patches/engine-config-validation.patch $(ENGINE_AUDIO_SAFETY_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_XDG_PATH_SAFETY_PATCH_STAMP): patches/engine-xdg-path-safety.patch $(ENGINE_CONFIG_VALIDATION_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_WAV_INPUT_SAFETY_PATCH_STAMP): patches/engine-wav-input-safety.patch $(ENGINE_XDG_PATH_SAFETY_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_EXCHANGE_API_SAFETY_PATCH_STAMP): patches/engine-exchange-api-safety.patch $(ENGINE_WAV_INPUT_SAFETY_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_ENUM_SENTINEL_SAFETY_PATCH_STAMP): patches/engine-enum-sentinel-safety.patch $(ENGINE_EXCHANGE_API_SAFETY_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_RESPONSIVE_STATION_LAYOUT_PATCH_STAMP): patches/engine-responsive-station-layout.patch $(ENGINE_ENUM_SENTINEL_SAFETY_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_ATOMIC_CALL_LIST_PATCH_STAMP): patches/engine-atomic-call-list-import.patch $(ENGINE_RESPONSIVE_STATION_LAYOUT_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_ATOMIC_INI_PATCH_STAMP): patches/engine-atomic-ini-write.patch $(ENGINE_ATOMIC_CALL_LIST_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_AUDIO_HEADER_PATCH_STAMP): patches/engine-audio-backend-header.patch $(ENGINE_ATOMIC_INI_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(ENGINE_STATION_LAYOUT_HEIGHT_PATCH_STAMP): patches/engine-station-layout-height.patch $(ENGINE_AUDIO_HEADER_PATCH_STAMP)
	sh scripts/apply-overlay.sh "$(ENGINE_DIR)" "$<"
	touch $@

$(CORE_BIN_DIR)/morserunner-linux: scripts/morserunner-linux-launcher
	mkdir -p $(CORE_BIN_DIR)
	install -m 755 $< $@

# Install a self-contained native Linux layout. The engine deliberately keeps
# its read-only contest files alongside its executable, while user state stays
# in the XDG data directory.
install: linux-app packaging/morserunner.desktop
	install -d "$(BINDIR)" "$(LIBEXECDIR)" "$(DATADIR)" "$(DESKTOPDIR)" "$(ICONDIR)" "$(METAINFODIR)"
	install -m 755 scripts/morserunner-linux-launcher "$(BINDIR)/morserunner"
	install -m 755 scripts/morserunner-linux-launcher "$(BINDIR)/morserunner-linux"
	install -m 755 $(ENGINE_BINARY) "$(LIBEXECDIR)/MorseRunner"
	install -m 644 $(addprefix $(ENGINE_DIR)/,$(ENGINE_RUNTIME_DATA)) "$(LIBEXECDIR)/"
	install -m 644 packaging/morserunner.desktop "$(DESKTOPDIR)/morserunner.desktop"
	install -m 644 $(ENGINE_DIR)/MorseRunner.png "$(ICONDIR)/morserunner.png"
	install -m 644 packaging/morserunner.metainfo.xml "$(METAINFODIR)/morserunner.metainfo.xml"

# A conventional Debian package keeps the engine and its contest files under
# /usr/lib, while the launcher and desktop integration remain in standard
# freedesktop locations. It is intentionally built from the same install
# target that users and CI exercise.
deb: check-package-arch linux-app packaging/debian/control.in packaging/debian/changelog.in packaging/debian/copyright
	test -n "$(DEB_ROOT)" && rm -rf "$(DEB_ROOT)"
	rm -f "$(DEB_OUTPUT)"
	install -d "$(DEB_ROOT)/DEBIAN" "$(PACKAGE_DIR)"
	sed -e 's/@VERSION@/$(PACKAGE_VERSION)/' -e 's/@ARCH@/$(DEB_ARCH)/' \
		-e 's|@MAINTAINER@|$(DEB_MAINTAINER)|' \
		packaging/debian/control.in > "$(DEB_ROOT)/DEBIAN/control"
	$(MAKE) install PREFIX="$(DEB_ROOT)/usr"
	install -d "$(DEB_ROOT)/usr/share/doc/morserunner-linux"
	sed -e 's/@VERSION@/$(PACKAGE_VERSION)/' \
		-e 's|@MAINTAINER@|$(DEB_MAINTAINER)|' \
		packaging/debian/changelog.in > "$(DEB_ROOT)/usr/share/doc/morserunner-linux/changelog.Debian"
	install -m 644 packaging/debian/copyright "$(DEB_ROOT)/usr/share/doc/morserunner-linux/copyright"
	install -m 644 LICENSE "$(DEB_ROOT)/usr/share/doc/morserunner-linux/MPL-2.0.txt"
	install -m 644 README.md "$(DEB_ROOT)/usr/share/doc/morserunner-linux/README.md"
	dpkg-deb --build --root-owner-group "$(DEB_ROOT)" "$(DEB_OUTPUT)"

# Validate an extracted package layout without touching the host installation.
deb-test: deb
	set -eu; stage=$$(mktemp -d /tmp/morserunner-deb-test.XXXXXX); \
	trap 'rm -rf "$$stage"' EXIT HUP INT TERM; \
	dpkg-deb -x "$(DEB_OUTPUT)" "$$stage"; \
	test -x "$$stage/usr/bin/morserunner"; \
	test -x "$$stage/usr/bin/morserunner-linux"; \
	test -x "$$stage/usr/lib/morserunner/MorseRunner"; \
	test -f "$$stage/usr/lib/morserunner/MASTER.SCP"; \
	desktop-file-validate "$$stage/usr/share/applications/morserunner.desktop"; \
	test -f "$$stage/usr/share/icons/hicolor/128x128/apps/morserunner.png"; \
	test -f "$$stage/usr/share/doc/morserunner-linux/copyright"; \
	test -f "$$stage/usr/share/doc/morserunner-linux/changelog.Debian"; \
	log="$$stage/launcher.log"; status=0; XDG_DATA_HOME="$$stage/data" XDG_STATE_HOME="$$stage/state" \
		MORSERUNNER_DEBUG=1 timeout 8s xvfb-run -a "$$stage/usr/bin/morserunner" >"$$log" 2>&1 || status=$$?; \
	test "$$status" = 124 || (cat "$$log" >&2; echo "Packaged application exited with $$status" >&2; exit 1); \
	echo "Debian package installs and reaches its GUI event loop"

# The AppImage is a portable x86_64 distribution built from the same installed
# layout. appimagetool is downloaded only into build/ and never committed.
$(APPIMAGE_TOOL):
	install -d "$(dir $@)"
	curl --fail --location --retry 3 --output "$@" \
		"$(APPIMAGE_TOOL_URL)"
	printf '%s  %s\n' "$(APPIMAGE_TOOL_SHA256)" "$@" | sha256sum --check --status
	chmod 755 "$@"

$(LINUXDEPLOY_TOOL):
	install -d "$(dir $@)"
	curl --fail --location --retry 3 --output "$@" "$(LINUXDEPLOY_URL)"
	printf '%s  %s\n' "$(LINUXDEPLOY_SHA256)" "$@" | sha256sum --check --status
	chmod 755 "$@"

appimage: check-package-arch check-appimage-tools linux-app $(APPIMAGE_TOOL)
	test -n "$(APPIMAGE_ROOT)" && rm -rf "$(APPIMAGE_ROOT)"
	rm -f "$(APPIMAGE_OUTPUT)"
	install -d "$(APPIMAGE_ROOT)"
	$(MAKE) install PREFIX="$(APPIMAGE_ROOT)/usr"
	install -d "$(APPIMAGE_ROOT)/usr/share/doc/morserunner-linux"
	install -m 644 LICENSE "$(APPIMAGE_ROOT)/usr/share/doc/morserunner-linux/MPL-2.0.txt"
	install -m 644 packaging/debian/copyright "$(APPIMAGE_ROOT)/usr/share/doc/morserunner-linux/copyright"
	install -m 644 packaging/morserunner.desktop "$(APPIMAGE_ROOT)/morserunner.desktop"
	install -m 644 $(ENGINE_DIR)/MorseRunner.png "$(APPIMAGE_ROOT)/morserunner.png"
	install -m 755 packaging/AppRun "$(APPIMAGE_ROOT)/AppRun"
	APPIMAGE_EXTRACT_AND_RUN=1 $(LINUXDEPLOY) --appdir "$(APPIMAGE_ROOT)" \
		--executable "$(APPIMAGE_ROOT)/usr/lib/morserunner/MorseRunner" \
		--desktop-file "$(APPIMAGE_ROOT)/morserunner.desktop" \
		--icon-file "$(APPIMAGE_ROOT)/morserunner.png"
	ARCH="$(APPIMAGE_ARCH)" APPIMAGE_EXTRACT_AND_RUN=1 "$(APPIMAGE_TOOL)" \
		"$(APPIMAGE_ROOT)" "$(APPIMAGE_OUTPUT)"

appimage-test: appimage
	set -eu; stage=$$(mktemp -d /tmp/morserunner-appimage-test.XXXXXX); \
	trap 'rm -rf "$$stage"' EXIT HUP INT TERM; \
	test -x "$(APPIMAGE_OUTPUT)"; \
	log="$$stage/launcher.log"; status=0; XDG_DATA_HOME="$$stage/data" XDG_STATE_HOME="$$stage/state" \
		MORSERUNNER_DEBUG=1 APPIMAGE_EXTRACT_AND_RUN=1 timeout 8s xvfb-run -a "$(APPIMAGE_OUTPUT)" >"$$log" 2>&1 || status=$$?; \
	test "$$status" = 124 || (cat "$$log" >&2; echo "AppImage application exited with $$status" >&2; exit 1); \
	echo "AppImage enters Morse Runner's GUI event loop"

# Retained only for testing the new audio seam while the old engine is migrated.
preview-app: check-toolchain
	mkdir -p $(CORE_UNIT_DIR) $(CORE_BIN_DIR)
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) MorseRunnerLinux.lpi

audio-smoke-test: check-toolchain
	mkdir -p $(CORE_UNIT_DIR) $(CORE_BIN_DIR)
	$(FPC) -Mdelphi -Fu$(CORE_SOURCE_DIR) -Fu$(LINUX_SOURCE_DIR) -FU$(CORE_UNIT_DIR) \
		-o$(CORE_BIN_DIR)/portaudio-device-smoke-tests tests/PortAudioDeviceSmokeTests.lpr
	$(CORE_BIN_DIR)/portaudio-device-smoke-tests

update-call-list:
	bash tools/update-super-check-partial.sh

container-build:
	$(CONTAINER_RUNTIME) build -t $(CONTAINER_IMAGE) -f tools/Dockerfile .

container-test: container-build
	$(CONTAINER_RUNTIME) run --rm --user "$(shell id -u):$(shell id -g)" \
		-e HOME=/tmp/morserunner-home -v "$(CURDIR):/workspace" -w /workspace \
		$(CONTAINER_IMAGE) sh -ec 'mkdir -p "$$HOME"; make bootstrap-toolchain; make core-test linux-app deb-test'

# This is the portable-release gate: artifacts are compiled against Debian
# 11's glibc 2.31 baseline, bundled, and then launched under Xvfb.
container-release: container-build
	$(CONTAINER_RUNTIME) run --rm --user "$(shell id -u):$(shell id -g)" \
		-e HOME=/tmp/morserunner-home -v "$(CURDIR):/workspace" -w /workspace \
		$(CONTAINER_IMAGE) sh -ec 'mkdir -p "$$HOME"; make bootstrap-toolchain; make appimage-test'

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(ENGINE_DIR)/linux/VCL/AudioBackendPulse.o $(ENGINE_DIR)/MorseRunner
	rm -rf $(ENGINE_DIR)/lib/x86_64-linux
	rm -f $(ENGINE_DIR)/MASTER.SCP $(ENGINE_DIR)/.morserunner-*-patch-applied
