#!/usr/bin/env sh
set -e

fpc_binary="$FPC"
if [ -z "$fpc_binary" ]; then
  fpc_binary=fpc
fi

fpc_version="$("$fpc_binary" -iV 2>/dev/null || true)"
if [ -z "$fpc_version" ]; then
  fpc_version="no version"
fi

case "$fpc_version" in
  3.2.*)
    ;;
  *)
    printf '%s\n' "Free Pascal 3.2.x is required; $fpc_binary reported: $fpc_version" >&2
    exit 1
    ;;
esac
