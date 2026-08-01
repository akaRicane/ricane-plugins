#!/usr/bin/env bash
#
# open.sh — launch the Standalone app of a JUCE plugin from the /bank folder.
#
# Two modes:
#   1) No argument  -> interactive menu of every plugin with a built Standalone
#   2) <plugin> arg -> open that specific plugin
#
set -euo pipefail

# Absolute paths derived from this script's location, so it works from any CWD.
# This script lives in utils/, so the repo root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BANK_DIR="$REPO_ROOT/bank"

usage() {
  cat <<'EOF'
open.sh — launch the Standalone app of a plugin in /bank

USAGE:
  ./utils/open.sh                  Interactive: pick a plugin from a menu
  ./utils/open.sh <plugin>         Open a specific plugin
  ./utils/open.sh -t <plugin>      Run it in this terminal so DBG/stdout is visible
  ./utils/open.sh -q <plugin>      Quit a running instance, don't relaunch
  ./utils/open.sh -h | --help      Show this help

OPTIONS:
  -t, --terminal             Run the executable inside the .app bundle directly, so
                             JUCE DBG()/std::cout output lands in this terminal.
                             Ctrl-C quits it. (Ignored with --quit.)
  -q, --quit                 Only quit the running instance, then exit.

<plugin> accepts any of:
  GainPlugin                 a folder name inside bank/
  bank/GainPlugin            a path with the bank/ prefix
  /abs/path/to/plugin        any directory containing a built Standalone

WHAT IT DOES:
  - Finds  <plugin>/build/<Target>_artefacts/Standalone/<Name>.app
  - Quits a stale instance first, so you always get the freshest build
  - Launches it detached (default) or in the foreground (--terminal)

This script never builds. If nothing is found, run ./utils/build.sh <plugin> first.
EOF
}

# Echo the first Standalone .app bundle under a plugin folder, or fail.
find_standalone() {
  local dir="$1" app="" candidate
  [ -d "$dir/build" ] || return 1
  # Read via process substitution rather than `| head` so `set -o pipefail`
  # can't trip on find receiving SIGPIPE when there are several matches.
  while IFS= read -r candidate; do
    app="$candidate"
    break
  done < <(find "$dir/build" -type d -name '*.app' -path '*Standalone*' 2>/dev/null | sort)
  [ -n "$app" ] || return 1
  printf '%s\n' "$app"
}

# Fill the PLUGINS array with folder names in bank/ that have a built Standalone.
list_plugins() {
  PLUGINS=()
  local d
  for d in "$BANK_DIR"/*/; do
    [ -d "$d" ] || continue
    if find_standalone "${d%/}" >/dev/null; then
      PLUGINS+=("$(basename "$d")")
    fi
  done
}

# Resolve a user argument to an absolute plugin directory (echoed on success).
resolve_plugin() {
  local input="$1"
  # 1) a real directory (absolute or relative to CWD)
  if [ -d "$input" ]; then
    (cd "$input" && pwd)
    return 0
  fi
  # 2) otherwise treat the last path component as a plugin name under bank/
  local name candidate
  name="$(basename "$input")"
  candidate="$BANK_DIR/$name"
  if [ -d "$candidate" ]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

# Close a running instance so we never look at a stale build.
quit_app() {
  local name="$1"
  if killall "$name" 2>/dev/null; then
    echo "==> Quit running $name"
  fi
}

main() {
  local in_terminal=false
  local quit_only=false
  local plugin_arg=""

  # Parse arguments: flags in any order, plus at most one plugin name.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -t|--terminal) in_terminal=true ;;
      -q|--quit) quit_only=true ;;
      -*)
        echo "error: unknown option '$1' (run ./utils/open.sh --help)" >&2
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
      echo "error: no plugin folder matches '$plugin_arg'" >&2
      echo "hint: run ./utils/open.sh with no arguments to list what is built." >&2
      exit 1
    fi
  else
    # Mode 1: interactive selector
    list_plugins
    if [ "${#PLUGINS[@]}" -eq 0 ]; then
      echo "error: no built Standalone app in $BANK_DIR." >&2
      echo "hint: build one first, e.g. ./utils/build.sh GainPlugin" >&2
      exit 1
    fi
    echo "Standalone apps in bank/:"
    PS3="Select a plugin to open (number): "
    local choice
    select choice in "${PLUGINS[@]}"; do
      if [ -n "${choice:-}" ]; then
        plugin_dir="$BANK_DIR/$choice"
        break
      fi
      echo "Invalid selection, try again."
    done
    # `select` also ends on Ctrl-D, which leaves nothing selected.
    if [ -z "$plugin_dir" ]; then
      echo "error: nothing selected." >&2
      exit 1
    fi
  fi

  local app
  if ! app="$(find_standalone "$plugin_dir")"; then
    echo "error: no Standalone .app under $plugin_dir/build" >&2
    echo "hint: build it first (./utils/build.sh $(basename "$plugin_dir")), and check" >&2
    echo "      that 'Standalone' is listed in FORMATS in its CMakeLists.txt." >&2
    exit 1
  fi

  local name
  name="$(basename "$app" .app)"
  echo "==> Plugin: $(basename "$plugin_dir")"
  echo "==> App:    $app"

  quit_app "$name"
  if [ "$quit_only" = true ]; then
    exit 0
  fi

  if [ "$in_terminal" = true ]; then
    echo "==> Running $name in this terminal (Ctrl-C to quit)"
    exec "$app/Contents/MacOS/$name"
  fi

  echo "==> Opening $name"
  open "$app"
}

main "$@"
