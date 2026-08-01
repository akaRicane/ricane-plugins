# Build Process (CMake + JUCE)

How to build and update a plugin in `/bank`. Each plugin is **self-contained**: its own
`CMakeLists.txt` that pulls JUCE in directly.

## Mental model

- **Configure = set up the workshop.** Run *once* per plugin (slow — it processes all of JUCE).
- **Build = make the thing.** Run after *every* code edit (fast — only recompiles what changed).

New plugin folder → configure once → build forever.

## The two commands

Run from the plugin folder, e.g. `cd /Users/ricane/Workspace/code/plugins/bank/GainPlugin`.

```bash
# 1. Configure — ONCE (first time setting up the project)
cmake -B build -S .
#   -S .      source dir (where CMakeLists.txt lives; "." = here)
#   -B build  build dir to generate

# 2. Build — EVERY code edit
cmake --build build
```

### Everyday loop
```bash
cd /Users/ricane/Workspace/code/plugins/bank/GainPlugin
cmake --build build
```
Edit code → `cmake --build build` → test.

## Good to know

- **Edited `CMakeLists.txt`?** Just run `cmake --build build` — CMake auto-reconfigures when it
  detects the change. You almost never run the configure command by hand again.
- **Faster builds** (use all CPU cores): `cmake --build build -j`
- **Clean slate** (rare — only if a build acts corrupted):
  ```bash
  rm -rf build && cmake -B build -S . && cmake --build build
  ```

## Where the outputs land

| Format | Path |
|---|---|
| Standalone app | `build/<Target>_artefacts/Standalone/<Product Name>.app` |
| VST3 | auto-installed to `~/Library/Audio/Plug-Ins/VST3/` (via `COPY_PLUGIN_AFTER_BUILD TRUE`) |

Launch the standalone: `open "build/GainPlugin_artefacts/Standalone/Gain Plugin.app"`

## Ableton (and other DAWs) won't refresh live

A running DAW keeps the loaded `.vst3` in memory; a new build on disk won't replace it until relaunch.
- **Quit and reopen the DAW** to pick up a new build (most reliable).
- If the *parameter list* is stale (added/removed a parameter): **Settings → Plug-Ins → ⌥-click "Rescan"** for a full rescan.
- For fast iteration, prefer the **Standalone** app — no caching, always runs the latest build.

## CMakeLists.txt reference (options we rely on)

Inside `juce_add_plugin(<Target> ...)`:

| Option | Why |
|---|---|
| `PRODUCT_NAME "Gain Plugin"` | Display name of the plugin |
| `COMPANY_NAME "Ricane"` | Manufacturer name shown in the host browser |
| `PLUGIN_MANUFACTURER_CODE Rcan` | 4-char registry ID (not user-visible) |
| `PLUGIN_CODE Gain` | 4-char plugin ID |
| `FORMATS VST3 Standalone` | Which formats to build |
| `IS_SYNTH FALSE` | Audio effect, not an instrument |
| `NEEDS_MIDI_INPUT/OUTPUT FALSE` | No MIDI |
| `MICROPHONE_PERMISSION_ENABLED TRUE` + `..._TEXT "..."` | macOS mic access for the **Standalone** (adds `NSMicrophoneUsageDescription`). Without it, macOS silently blocks input → dead VU meter. |
| `COPY_PLUGIN_AFTER_BUILD TRUE` | Auto-installs the built VST3 to `~/Library/Audio/Plug-Ins/VST3/` |

Outside the plugin block:

```cmake
add_subdirectory(../../JUCE JUCE)     # pull JUCE in (path is relative to THIS file)
target_compile_features(<Target> PRIVATE cxx_std_17)
target_compile_definitions(<Target> PUBLIC JUCE_VST3_CAN_REPLACE_VST2=0)  # avoids VST2/VST3 automation conflict #error
target_link_libraries(<Target> PRIVATE
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags)
```

### Gotchas learned
- **`JUCE_VST3_CAN_REPLACE_VST2=0`** — without it the VST3 target fails with a hard
  `#error` about "parameter automation conflict between VST2 and VST3." We have no VST2 past, so set it to 0.
- **`add_subdirectory` path** — relative to the plugin's `CMakeLists.txt`. From `bank/<Plugin>/`
  that's `../../JUCE` (up to `bank/`, up to repo root, into `JUCE/`).
- **Empty `JUCE/`** — it's a git submodule pinned to the `8.0.13` tag, so a plain `git clone`
  leaves it empty and configure fails on the `add_subdirectory` above. Fix with
  `git submodule update --init` (or clone with `--recursive` next time).

## Starting a new plugin in /bank

1. `mkdir -p bank/<Name>/src`
2. Write `bank/<Name>/CMakeLists.txt` (copy an existing one; change target/product/plugin codes and the `src/` file list).
3. Write your `src/*.h` / `src/*.cpp`.
4. `cd bank/<Name> && cmake -B build -S .` (configure once), then `cmake --build build`.
