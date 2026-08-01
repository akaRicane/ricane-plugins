#!/usr/bin/env bash
#
# validate.sh — run pluginval against a JUCE plugin from the /bank folder.
#
# pluginval loads the built plugin and abuses it the way a strict host would:
# every sample-rate x block-size combination, parameter fuzzing, state save/
# restore round-trips, editor open/close, and (via rtcheck) allocations or
# locks on the audio thread. See documentation/tools/pluginval.md.
#
# Two modes, same as build.sh:
#   1) No argument  -> interactive menu of every plugin in bank/
#   2) <plugin> arg -> validate that specific plugin
#
set -euo pipefail

# Absolute paths derived from this script's location, so it works from any CWD.
# This script lives in utils/, so the repo root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BANK_DIR="$REPO_ROOT/bank"

# Validation uses its own build tree, separate from the normal build/ one, so
# turning validation on never slows down everyday builds.
BUILD_DIR_NAME="build-pluginval"

usage() {
  cat <<'EOF'
validate.sh — run pluginval against a JUCE plugin in /bank

USAGE:
  ./utils/validate.sh                    Interactive: pick a plugin from a menu
  ./utils/validate.sh <plugin>           Validate a specific plugin
  ./utils/validate.sh -s 10 <plugin>     Validate at maximum strictness
  ./utils/validate.sh -h | --help        Show this help

OPTIONS:
  -s, --strictness <1-10>    How hard to push. 5 (default) is pluginval's
                             recommended minimum for host compatibility;
                             6+ adds parameter fuzzing; 10 is the most thorough.
  -r, --rtcheck <mode>       Real-time safety checks: relaxed (default), enabled
                             or disabled. 'relaxed' ignores allocations in the
                             very first processed block, which most plugins do
                             legitimately; 'enabled' flags those too.
      --repeat <n>           Run the whole suite n extra times.
      --randomise            Shuffle test order each repeat. Combined with
                             --repeat, this shakes out order-dependent bugs.
      --verbose              More logging from pluginval.
  -c, --configure            Force a re-configure of the validation build tree.
  -i, --in-process           Don't fork a child process to host the plugin. Use
                             this when running under a debugger, so a crash
                             stops in your own code. Off by default, because a
                             crashing plugin then takes pluginval down with it.

<plugin> accepts any of:
  GainPlugin                        a folder name inside bank/
  bank/GainPlugin                   a path with the bank/ prefix
  documentation/example_plugin      any directory containing a CMakeLists.txt

WHAT IT DOES:
  - Configures <plugin>/build-pluginval/ with -DENABLE_PLUGINVAL=ON (first run
    only, or with -c). This builds pluginval itself: a whole JUCE application,
    so the first run takes several minutes and ~280 MB.
  - Builds the plugin's VST3 and pluginval, then validates the VST3.

EXIT CODE:
  0 if every test passed, non-zero otherwise — so this is CI-friendly, and
  worth trusting over skim-reading the log.
EOF
}

# Fill the PLUGINS array with folder names in bank/ that contain a CMakeLists.txt.
list_plugins() {
  PLUGINS=()
  local d
  for d in "$BANK_DIR"/*/; do
    if [ -f "${d}CMakeLists.txt" ]; then
      PLUGINS+=("$(basename "$d")")
    fi
  done
}

# Resolve a user argument to an absolute plugin directory (echoed on success).
resolve_plugin() {
  local input="$1"
  # 1) a real directory (absolute or relative to CWD) holding a CMakeLists.txt
  if [ -d "$input" ] && [ -f "$input/CMakeLists.txt" ]; then
    (cd "$input" && pwd)
    return 0
  fi
  # 2) otherwise treat the last path component as a plugin name under bank/
  local name candidate
  name="$(basename "$input")"
  candidate="$BANK_DIR/$name"
  if [ -d "$candidate" ] && [ -f "$candidate/CMakeLists.txt" ]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

# Read the CMake project() name, which is also the juce_add_plugin target name
# and therefore the prefix of the <Target>_artefacts folder and _VST3 target.
project_name() {
  local dir="$1"
  sed -n -E 's/^[[:space:]]*project[[:space:]]*\([[:space:]]*([A-Za-z0-9_]+).*/\1/p' \
    "$dir/CMakeLists.txt" | head -n 1
}

main() {
  local strictness=5
  local rtcheck="relaxed"
  local repeat=""
  local randomise=false
  local verbose=false
  local in_process=false
  local force_configure=false
  local plugin_arg=""

  # Parse arguments: flags in any order, plus at most one plugin name.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -s|--strictness) strictness="${2:-}"; shift ;;
      -r|--rtcheck) rtcheck="${2:-}"; shift ;;
      --repeat) repeat="${2:-}"; shift ;;
      --randomise|--randomize) randomise=true ;;
      --verbose) verbose=true ;;
      -c|--configure) force_configure=true ;;
      -i|--in-process) in_process=true ;;
      -*)
        echo "error: unknown option '$1' (run ./utils/validate.sh --help)" >&2
        exit 1
        ;;
      *)
        if [ -z "$plugin_arg" ]; then
          plugin_arg="$1"
        else
          echo "error: unexpected extra argument '$1'" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  case "$strictness" in
    ''|*[!0-9]*) echo "error: --strictness needs a number 1-10 (got '$strictness')" >&2; exit 1 ;;
  esac
  if [ "$strictness" -lt 1 ] || [ "$strictness" -gt 10 ]; then
    echo "error: --strictness must be between 1 and 10 (got '$strictness')" >&2
    exit 1
  fi

  case "$rtcheck" in
    relaxed|enabled|disabled) ;;
    *) echo "error: --rtcheck must be relaxed, enabled or disabled (got '$rtcheck')" >&2; exit 1 ;;
  esac

  if [ ! -d "$BANK_DIR" ]; then
    echo "error: bank folder not found at $BANK_DIR" >&2
    exit 1
  fi

  local plugin_dir=""

  if [ -n "$plugin_arg" ]; then
    # Mode 2: explicit plugin argument
    if ! plugin_dir="$(resolve_plugin "$plugin_arg")"; then
      echo "error: no plugin (folder with a CMakeLists.txt) matches '$plugin_arg'" >&2
      echo "hint: run ./utils/validate.sh with no arguments to list available plugins." >&2
      exit 1
    fi
  else
    # Mode 1: interactive selector
    list_plugins
    if [ "${#PLUGINS[@]}" -eq 0 ]; then
      echo "error: no plugins in $BANK_DIR (need a sub-folder with a CMakeLists.txt)." >&2
      exit 1
    fi
    echo "Plugins in bank/:"
    PS3="Select a plugin to validate (number): "
    local choice
    select choice in "${PLUGINS[@]}"; do
      if [ -n "${choice:-}" ]; then
        plugin_dir="$BANK_DIR/$choice"
        break
      fi
      echo "Invalid selection, try again."
    done
  fi

  local target
  target="$(project_name "$plugin_dir")"
  if [ -z "$target" ]; then
    echo "error: could not read the project() name from $plugin_dir/CMakeLists.txt" >&2
    exit 1
  fi

  local build_dir="$plugin_dir/$BUILD_DIR_NAME"

  echo "==> Plugin: $(basename "$plugin_dir")  (target: $target)"
  echo "==> Folder: $plugin_dir"

  if [ "$force_configure" = true ] || [ ! -d "$build_dir" ]; then
    echo "==> Configuring with -DENABLE_PLUGINVAL=ON…"
    echo "    (first run builds pluginval itself — expect several minutes)"
    cmake -S "$plugin_dir" -B "$build_dir" -DENABLE_PLUGINVAL=ON
  fi

  echo "==> Building the VST3 and pluginval…"
  cmake --build "$build_dir" --target "${target}_VST3" pluginval --parallel

  # Locate the two things we need. Both are found rather than hardcoded, so a
  # PRODUCT_NAME that differs from the target name still works.
  local pluginval_bin plugin_artefact
  pluginval_bin="$(find "$build_dir" -type f -perm -111 -path '*pluginval.app/Contents/MacOS/pluginval' 2>/dev/null | head -n 1)"
  if [ -z "$pluginval_bin" ]; then
    echo "error: pluginval binary not found under $build_dir" >&2
    exit 1
  fi

  plugin_artefact="$(find "$build_dir/${target}_artefacts" -maxdepth 3 -type d -name '*.vst3' 2>/dev/null | head -n 1)"
  if [ -z "$plugin_artefact" ]; then
    echo "error: no .vst3 found under $build_dir/${target}_artefacts" >&2
    exit 1
  fi

  # Assemble the pluginval invocation.
  local args=(--strictness-level "$strictness" --rtcheck "$rtcheck")
  [ -n "$repeat" ] && args+=(--repeat "$repeat")
  [ "$randomise" = true ] && args+=(--randomise)
  [ "$verbose" = true ] && args+=(--verbose)
  [ "$in_process" = true ] && args+=(--validate-in-process)
  args+=(--validate "$plugin_artefact")

  echo "==> Validating: $(basename "$plugin_artefact")"
  echo "    strictness=$strictness rtcheck=$rtcheck"

  # Don't let a failure abort the script before we can report it nicely.
  set +e
  "$pluginval_bin" "${args[@]}"
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "==> PASSED (strictness $strictness)"
  else
    echo "==> FAILED (exit $status). The last 'Starting tests in:' line above names the group that broke." >&2
    echo "    Narrow it down with e.g. --verbose, or -i to run under a debugger." >&2
  fi
  exit "$status"
}

main "$@"
