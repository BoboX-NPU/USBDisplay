#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_ARGS=(
  -project "$ROOT_DIR/USBDisplay.xcodeproj"
  -scheme "USB Display"
  -configuration Debug
  -destination "platform=macOS,arch=$(uname -m)"
)

usage() {
  cat <<'EOF'
Usage: ./script/test.sh [-only-testing:TARGET[/SUITE[/TEST]]] [-skip-testing:TARGET[/SUITE[/TEST]]]

Run macOS tests in an isolated temporary build directory. Build caches and
test results are deleted on success, failure, or HUP/INT/TERM interruption.
Test output remains in the terminal; redirect it to a file if needed.
The persistent .build/Xcode and .build/Distribution directories are not used.
EOF
}

for argument in "$@"; do
  case "$argument" in
    -h|--help)
      usage
      exit 0
      ;;
    -only-testing:?*|-skip-testing:?*)
      XCODE_ARGS+=("$argument")
      ;;
    *)
      printf 'Unsupported argument: %s\n' "$argument" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TEST_DIR=""
XCODE_PID=""
cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  # Stop and reap an interrupted build before deleting files it may still use.
  if [[ -n "$XCODE_PID" ]]; then
    kill -TERM "$XCODE_PID" 2>/dev/null || true
    wait "$XCODE_PID" 2>/dev/null || true
  fi
  if [[ -n "$TEST_DIR" ]]; then
    if rm -rf -- "$TEST_DIR"; then
      printf '\nRemoved temporary test artifacts: %s\n' "$TEST_DIR"
    else
      printf '\nCould not remove temporary test artifacts: %s\n' "$TEST_DIR" >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$ROOT_DIR/.build"
TEST_DIR="$(mktemp -d "$ROOT_DIR/.build/TestRun.XXXXXX")"
printf 'Temporary test artifacts: %s\n' "$TEST_DIR"

xcodebuild "${XCODE_ARGS[@]}" \
  -derivedDataPath "$TEST_DIR/DerivedData" \
  -resultBundlePath "$TEST_DIR/Tests.xcresult" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  ENABLE_HARDENED_RUNTIME=NO \
  test &
XCODE_PID=$!
status=0
wait "$XCODE_PID" || status=$?
XCODE_PID=""
exit "$status"
