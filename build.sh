#!/usr/bin/env bash
#
# build.sh — configure & build a JUCE plugin from the /bank folder.
#
# Two modes:
#   1) No argument  -> interactive menu of every plugin in bank/
#   2) <plugin> arg -> build that specific plugin
#
set -euo pipefail

# Absolute path to this script's directory, so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANK_DIR="$SCRIPT_DIR/bank"

usage() {
  cat <<'EOF'
build.sh — configure & build a JUCE plugin in /bank

USAGE:
  ./build.sh                 Interactive: pick a plugin from a menu
  ./build.sh <plugin>        Build a specific plugin
  ./build.sh -o <plugin>     Build, then open the Standalone app
  ./build.sh -h | --help     Show this help

OPTIONS:
  -o, --open                 After a successful build, launch the Standalone app
                             (relaunches it if already running). Works in both modes.

<plugin> accepts any of:
  GainPlugin                 a folder name inside bank/
  bank/GainPlugin            a path with the bank/ prefix
  /abs/path/to/plugin        any directory containing a CMakeLists.txt

WHAT IT DOES:
  - Configures the plugin the first time only  (cmake -B build -S .)
  - Builds it every run                        (cmake --build build --parallel)
  - Outputs:
      Standalone -> <plugin>/build/<Target>_artefacts/Standalone/
      VST3       -> ~/Library/Audio/Plug-Ins/VST3/  (if COPY_PLUGIN_AFTER_BUILD is on)

A "plugin" is any sub-folder of bank/ that contains a CMakeLists.txt.
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

build_plugin() {
  local dir="$1"
  echo "==> Plugin: $(basename "$dir")"
  echo "==> Folder: $dir"
  if [ ! -d "$dir/build" ]; then
    echo "==> Configuring (first build, this is the slow one)…"
    cmake -S "$dir" -B "$dir/build"
  fi
  echo "==> Building…"
  cmake --build "$dir/build" --parallel
  echo "==> Done."
}

# Launch the plugin's Standalone .app (relaunching if already running).
open_standalone() {
  local dir="$1"
  local app
  app="$(find "$dir/build" -type d -name '*.app' -path '*Standalone*' 2>/dev/null | head -n 1)"
  if [ -z "$app" ]; then
    echo "warning: no Standalone .app found under $dir/build (is 'Standalone' in FORMATS?)" >&2
    return 0
  fi
  local name
  name="$(basename "$app" .app)"
  echo "==> Opening $name"
  killall "$name" 2>/dev/null || true   # close a stale instance so we relaunch the fresh build
  open "$app"
}

main() {
  local open_after=false
  local plugin_arg=""

  # Parse arguments: flags in any order, plus at most one plugin name.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -o|--open) open_after=true ;;
      -*)
        echo "error: unknown option '$1' (run ./build.sh --help)" >&2
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

  if [ ! -d "$BANK_DIR" ]; then
    echo "error: bank folder not found at $BANK_DIR" >&2
    exit 1
  fi

  local plugin_dir=""

  if [ -n "$plugin_arg" ]; then
    # Mode 2: explicit plugin argument
    if ! plugin_dir="$(resolve_plugin "$plugin_arg")"; then
      echo "error: no plugin (folder with a CMakeLists.txt) matches '$plugin_arg'" >&2
      echo "hint: run ./build.sh with no arguments to list available plugins." >&2
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
    PS3="Select a plugin to build (number): "
    local choice
    select choice in "${PLUGINS[@]}"; do
      if [ -n "${choice:-}" ]; then
        plugin_dir="$BANK_DIR/$choice"
        break
      fi
      echo "Invalid selection, try again."
    done
  fi

  build_plugin "$plugin_dir"

  if [ "$open_after" = true ]; then
    open_standalone "$plugin_dir"
  fi
}

main "$@"
