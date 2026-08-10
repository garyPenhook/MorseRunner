#!/usr/bin/env bash
set -Eeuo pipefail

readonly source_url='https://supercheckpartial.com/MASTER.SCP'
readonly data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
readonly data_dir="${data_home}/morserunner"
readonly target_file="${data_dir}/MASTER.SCP"
temporary_file=''

usage() {
  printf 'Usage: %s\nDownloads the current Super Check Partial call list to %s.\n' \
    "${0##*/}" "${target_file}" >&2
}

main() {
  if [[ "${1:-}" == '--help' ]]; then
    usage
    return 0
  fi
  if [[ $# -ne 0 ]]; then
    usage
    return 2
  fi
  if ! command -v curl >/dev/null; then
    printf 'curl is required to download MASTER.SCP.\n' >&2
    return 127
  fi

  mkdir -p -- "${data_dir}"
  temporary_file="$(mktemp "${data_dir}/MASTER.SCP.XXXXXX")"
  trap 'rm -f -- "${temporary_file}"' EXIT

  curl --fail --location --proto '=https' --tlsv1.2 --output "${temporary_file}" \
    "${source_url}"

  if ! grep -Eq $'^!!Order,1,1\r?$' "${temporary_file}"; then
    printf 'Downloaded file is not a recognized Super Check Partial list.\n' >&2
    return 1
  fi

  local call_count
  call_count="$(awk '{ sub(/\r$/, "") } /^[A-Z0-9/]+$/ { count += 1 } END { print count + 0 }' \
    "${temporary_file}")"
  if ((call_count < 1000)); then
    printf 'Downloaded list contains only %d calls; refusing to replace the local list.\n' \
      "${call_count}" >&2
    return 1
  fi

  mv -f -- "${temporary_file}" "${target_file}"
  trap - EXIT
  printf 'Installed %d contest calls at %s\n' "${call_count}" "${target_file}"
}

main "$@"
