#!/usr/bin/env sh
set -eu

LAZARUS_COMMIT=62c14a4d18c81f222127d42ce9b89b922c63fcbf
LAZARUS_URL=https://gitlab.com/freepascal.org/lazarus/lazarus.git
TOOLCHAIN_DIR=${1:-.toolchain}
LAZARUS_DIR="$TOOLCHAIN_DIR/lazarus-4.8"

if ! command -v git >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap-toolchain: git is required.' >&2
  exit 1
fi

if [ -d "$LAZARUS_DIR/.git" ]; then
  ACTUAL_COMMIT=$(git -C "$LAZARUS_DIR" rev-parse HEAD)
  if [ "$ACTUAL_COMMIT" != "$LAZARUS_COMMIT" ]; then
    printf '%s\n' "bootstrap-toolchain: $LAZARUS_DIR is at $ACTUAL_COMMIT, expected $LAZARUS_COMMIT." >&2
    exit 1
  fi
else
  mkdir -p "$TOOLCHAIN_DIR"
  git init "$LAZARUS_DIR"
  git -C "$LAZARUS_DIR" remote add origin "$LAZARUS_URL"
  git -C "$LAZARUS_DIR" fetch --depth 1 origin "$LAZARUS_COMMIT"
  git -C "$LAZARUS_DIR" checkout --detach FETCH_HEAD
fi

if ! command -v fpc >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap-toolchain: install Free Pascal (fpc) first.' >&2
  exit 1
fi

make -C "$LAZARUS_DIR" lazbuild
