#!/usr/bin/env bash
#
# new_plugin.sh — scaffold a new plugin in /bank from documentation/example_plugin.
#
# Copies the annotated template, renames every identifier in it, picks a unique
# 4-char PLUGIN_CODE, and registers the new build with the editor's IntelliSense.
#
# Interactive by design: it asks four questions, each with a sensible default
# deduced from the plugin name, so the usual answer is four presses of Enter.
#
set -euo pipefail

# Absolute paths derived from this script's location, so it works from any CWD.
# This script lives in utils/, so the repo root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BANK_DIR="$REPO_ROOT/bank"
TEMPLATE_DIR="$REPO_ROOT/documentation/example_plugin"
VSCODE_SETTINGS="$REPO_ROOT/.vscode/settings.json"

usage() {
  cat <<'EOF'
new_plugin.sh — scaffold a new plugin in /bank from the example_plugin template

USAGE:
  ./utils/new_plugin.sh                Interactive: asks for everything
  ./utils/new_plugin.sh <Name>         Use <Name>, still asks to confirm the rest
  ./utils/new_plugin.sh -h | --help    Show this help

IT ASKS FOR:
  Folder / target name       e.g. DelayPlugin. Also the CMake project() and
                             juce_add_plugin() target name, so it must be a
                             valid identifier: letters, digits, underscore.
  Class prefix               e.g. Delay -> DelayAudioProcessor and
                             DelayAudioProcessorEditor. Deduced by dropping a
                             trailing "Plugin" from the folder name.
  Product name               The name shown in the DAW, e.g. "Delay Plugin".
                             Deduced by splitting the folder name on capitals.
  PLUGIN_CODE                The 4-character plugin ID. Deduced from the class
                             prefix, and checked against every existing plugin
                             -- two plugins sharing a code confuses hosts.

WHAT IT DOES:
  - Copies documentation/example_plugin/ to bank/<Name>/ (without build trees)
  - Renames NewPluginProcessor -> <Prefix>AudioProcessor, and the editor to
    match, which is the convention the other plugins in bank/ already use
  - Rewrites the CMakeLists: project, target, PRODUCT_NAME, PLUGIN_CODE, and
    the template's own header comment
  - Adds the new build to .vscode/settings.json so IntelliSense resolves juce::

It never overwrites an existing plugin, and never builds. See
documentation/setup/starter_template.md for what to do next.
EOF
}

die() {
  echo "error: $1" >&2
  [ "$#" -gt 1 ] && echo "hint: $2" >&2
  exit 1
}

# Ask a question with a default; the answer is echoed on stdout.
# Prompts go to stderr so command substitution only captures the answer.
ask() {
  local prompt="$1" default="$2" answer=""
  printf '%s [%s]: ' "$prompt" "$default" >&2
  read -r answer || true
  printf '%s\n' "${answer:-$default}"
}

# Collect the PLUGIN_CODEs already in use, one per line.
existing_codes() {
  grep -h -E '^[[:space:]]*PLUGIN_CODE[[:space:]]+' \
    "$BANK_DIR"/*/CMakeLists.txt "$TEMPLATE_DIR/CMakeLists.txt" 2>/dev/null \
    | awk '{print $2}'
}

# "DelayPlugin" -> "Delay Plugin"  (split on lower/digit followed by upper)
split_capitals() {
  printf '%s\n' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g'
}

# Register the new plugin's compile_commands.json with the editor.
# settings.json is JSONC (it has comments), so this is a line edit, not jq.
add_to_vscode() {
  local name="$1"
  local entry_path="\${workspaceFolder}/bank/$name/build/compile_commands.json"

  if [ ! -f "$VSCODE_SETTINGS" ]; then
    echo "note: no .vscode/settings.json — skipping IntelliSense registration."
    echo "      (see documentation/setup/editor_setup.md)"
    return 0
  fi

  if grep -q "bank/$name/build/compile_commands.json" "$VSCODE_SETTINGS"; then
    echo "==> .vscode/settings.json already lists $name"
    return 0
  fi

  # Anchor on the last existing bank/ entry in the compileCommands array.
  local anchor
  anchor="$(grep -n 'bank/.*compile_commands\.json' "$VSCODE_SETTINGS" | tail -n 1 | cut -d: -f1 || true)"
  if [ -z "$anchor" ]; then
    echo "warning: could not find the compileCommands array in .vscode/settings.json." >&2
    echo "         Add this line yourself:" >&2
    echo "           \"$entry_path\"," >&2
    return 0
  fi

  # If the anchor is the array's last element it has no trailing comma, so it
  # needs one before ours is appended; otherwise ours carries the comma.
  local tmp="$VSCODE_SETTINGS.tmp.$$"
  awk -v ln="$anchor" -v path="$entry_path" '
    NR == ln {
      line = $0
      if (line !~ /,[[:space:]]*$/) {
        print line ","
        print "    \"" path "\""
      } else {
        print line
        print "    \"" path "\","
      }
      next
    }
    { print }
  ' "$VSCODE_SETTINGS" > "$tmp" && mv "$tmp" "$VSCODE_SETTINGS"

  echo "==> Registered with .vscode/settings.json (reload the window to pick it up)"
}

main() {
  local name_arg=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option '$1'" "run ./utils/new_plugin.sh --help" ;;
      *)
        if [ -z "$name_arg" ]; then
          name_arg="$1"
        else
          die "unexpected extra argument '$1'"
        fi
        ;;
    esac
    shift
  done

  [ -d "$TEMPLATE_DIR" ] || die "template not found at $TEMPLATE_DIR"
  [ -d "$BANK_DIR" ] || die "bank folder not found at $BANK_DIR"

  # ── 1. Folder / target name ────────────────────────────────────────────
  local name="$name_arg"
  while true; do
    [ -n "$name" ] || name="$(ask "Plugin folder & target name" "DelayPlugin")"
    if ! printf '%s' "$name" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
      echo "error: '$name' is not a valid CMake target name (letters, digits, underscore; no leading digit)." >&2
      name=""
      continue
    fi
    if [ -e "$BANK_DIR/$name" ]; then
      echo "error: bank/$name already exists — pick another name." >&2
      name=""
      continue
    fi
    break
  done

  # ── 2. Class prefix ────────────────────────────────────────────────────
  # DelayPlugin -> Delay, so the classes become DelayAudioProcessor and
  # DelayAudioProcessorEditor, matching the other plugins in bank/.
  local default_prefix="${name%Plugin}"
  [ -n "$default_prefix" ] || default_prefix="$name"
  local prefix
  while true; do
    prefix="$(ask "Class prefix (-> ${default_prefix}AudioProcessor)" "$default_prefix")"
    if printf '%s' "$prefix" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
      break
    fi
    echo "error: '$prefix' is not a valid C++ identifier." >&2
  done
  local class_proc="${prefix}AudioProcessor"
  local class_editor="${prefix}AudioProcessorEditor"

  # ── 3. Product name (what the DAW shows) ───────────────────────────────
  local product
  product="$(ask "Product name (shown in the DAW)" "$(split_capitals "$name")")"

  # ── 4. PLUGIN_CODE — 4 chars, unique across every plugin ───────────────
  # Deduce from the prefix: first 4 letters, first capitalised. Pad short ones.
  local base_code
  base_code="$(printf '%s' "$prefix" | tr -cd '[:alnum:]' | cut -c1-4)"
  while [ "${#base_code}" -lt 4 ]; do base_code="${base_code}x"; done
  base_code="$(printf '%s' "$base_code" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"

  local code
  while true; do
    code="$(ask "PLUGIN_CODE (4 chars, unique)" "$base_code")"
    if [ "${#code}" -ne 4 ]; then
      echo "error: PLUGIN_CODE must be exactly 4 characters (got '${code}')." >&2
      continue
    fi
    if existing_codes | grep -qx "$code"; then
      echo "error: PLUGIN_CODE '$code' is already used by another plugin." >&2
      echo "hint: in use — $(existing_codes | tr '\n' ' ')" >&2
      continue
    fi
    break
  done

  # ── Confirm ────────────────────────────────────────────────────────────
  local dest="$BANK_DIR/$name"
  cat <<EOF

About to create bank/$name
  target / project   $name
  classes            $class_proc, $class_editor
  PRODUCT_NAME       "$product"
  PLUGIN_CODE        $code
EOF
  local go
  go="$(ask "Proceed?" "y")"
  case "$go" in
    y|Y|yes|Yes) ;;
    *) echo "Aborted; nothing was created."; exit 0 ;;
  esac

  # ── Copy the template, without any build trees ─────────────────────────
  echo "==> Copying template to bank/$name"
  cp -R "$TEMPLATE_DIR" "$dest"
  rm -rf "$dest"/build "$dest"/build-* 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true

  # ── Rename identifiers in the sources ──────────────────────────────────
  # Longest first: NewPluginProcessor/NewPluginEditor must be rewritten before
  # any bare "NewPlugin" replacement could corrupt them.
  echo "==> Renaming classes"
  find "$dest/src" -type f \( -name '*.h' -o -name '*.cpp' \) -exec sed -i '' \
    -e "s/NewPluginProcessor/$class_proc/g" \
    -e "s/NewPluginEditor/$class_editor/g" \
    {} +

  # ── Rewrite the CMakeLists ─────────────────────────────────────────────
  echo "==> Rewriting CMakeLists.txt"
  local cml="$dest/CMakeLists.txt"

  # Replace the template's own header banner with a plugin-specific one, and
  # drop the "CHANGE THIS" note on PLUGIN_CODE now that we have set a real one.
  #
  # Note: plain "NewPlugin" -> "$name" is safe here because the CMakeLists
  # never mentions NewPluginProcessor/NewPluginEditor -- only the bare target.
  # It is written without \b word boundaries on purpose: BSD sed (macOS) does
  # not support them and fails silently, which this script used to do.
  sed -i '' \
    -e "s|^# EXAMPLE / TEMPLATE plugin .*|# $name — CMake build description|" \
    -e "s|^# Copy this whole folder into bank/<Name>/ and rename to start a real plugin\.|# A self-contained JUCE plugin: this file pulls JUCE in and describes the plugin.|" \
    -e '/^# See documentation\/setup\/starter_template\.md for the step-by-step\.$/d' \
    -e '/^ *# unique per plugin (two plugins sharing a$/d' \
    -e '/^ *# code confuses hosts)$/d' \
    -e "s|PLUGIN_CODE Newp .*|PLUGIN_CODE $code                    # 4-char plugin ID — must be UNIQUE per plugin|" \
    -e "s|\"New Plugin\"|\"$product\"|g" \
    -e "s|New Plugin needs microphone access|$product needs microphone access|g" \
    -e "s|NewPlugin|$name|g" \
    "$cml"

  # ── Editor integration ─────────────────────────────────────────────────
  add_to_vscode "$name"

  # ── Sanity check: nothing template-shaped left behind ──────────────────
  if grep -rq 'NewPlugin\|New Plugin\|Newp' "$dest" 2>/dev/null; then
    echo
    echo "warning: some template names survived the rename:" >&2
    grep -rn 'NewPlugin\|New Plugin\|Newp' "$dest" >&2 || true
    echo "         Fix these by hand before building." >&2
  fi

  cat <<EOF

==> Created bank/$name

Next:
  ./utils/build.sh -o $name        build it and open the Standalone
  ./utils/validate.sh $name        check it behaves in a real host

Then write the DSP — the markers in src/PluginProcessor.cpp show where:
  createParameterLayout()   add parameters
  prepareToPlay()           anything that depends on sample rate / block size
  processBlock()            the audio itself

  Reminder: if processBlock indexes a channel by number (getWritePointer(1)),
  implement isBusesLayoutSupported too, or a host handing you a mono buffer
  will read off the end of it.

Finally, the documentation is NOT updated automatically. Please update it
(or ask Claude to):
  documentation/plugins/$(printf '%s' "$name" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]').md   a page for this plugin
  documentation/README.md                    add it to the plugins/ index
  documentation/roadmap.md                   move it out of "Next", note any known gaps
  README.md                                  add a row to the plugin table
EOF
}

main "$@"
