LOCAL_FPC := $(CURDIR)/.toolchain/fpc-3.2.2/bin/fpc
LOCAL_FPC_BIN_DIR := $(dir $(LOCAL_FPC))
LOCAL_LAZARUS_DIR := $(CURDIR)/.toolchain/lazarus-4.8
LOCAL_LAZBUILD := $(LOCAL_LAZARUS_DIR)/lazbuild
ifeq ($(wildcard $(LOCAL_FPC)),)
FPC ?= fpc
else
FPC ?= $(LOCAL_FPC)
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

BUILD_DIR := build
CORE_UNIT_DIR := $(BUILD_DIR)/units
CORE_BIN_DIR := $(BUILD_DIR)/bin
CORE_SOURCE_DIR := src/core
LINUX_SOURCE_DIR := src/linux

.PHONY: check-toolchain core-test lazarus-core-test linux-app audio-smoke-test update-call-list container-build container-test clean

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
	PATH="$(LOCAL_FPC_BIN_DIR):$$PATH" $(LAZBUILD) $(LAZBUILD_ARGS) tests/PortAudioOutputTests.lpi
	$(CORE_BIN_DIR)/portaudio-output-tests

linux-app: check-toolchain
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
	$(CONTAINER_RUNTIME) run --rm -v "$(CURDIR):/workspace" \
		-w /workspace $(CONTAINER_IMAGE) make core-test

clean:
	rm -rf $(BUILD_DIR)
