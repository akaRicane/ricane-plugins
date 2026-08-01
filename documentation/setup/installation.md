# Installation

Getting from nothing to a built, validated plugin.

## Requirements

| | |
|---|---|
| **macOS** | The build scripts and `open.sh` are macOS-specific (`open`, `killall`, `.app` bundles) |
| **Xcode command-line tools** | Provides the C++17 compiler. `xcode-select --install` |
| **CMake ≥ 3.22** | Required by JUCE 8. `brew install cmake` |
| **Git** | The framework and validator are submodules |

Check what you have:

```bash
clang --version     # Apple clang
cmake --version     # must be >= 3.22
```

## Clone

`JUCE/` and `tools/pluginval/` are **git submodules**, so clone recursively:

```bash
git clone --recursive <repo-url> plugins
cd plugins
```

Already cloned without `--recursive`? Fetch them after the fact:

```bash
git submodule update --init
```

Confirm both are populated:

```bash
git submodule status
#  7c9d378... JUCE (8.0.13)
#  4c5adc2... tools/pluginval (v1.0.4-50-g4c5adc2)
```

A leading `-` on either line means it is **not** checked out yet, and nothing will configure —
every plugin's `CMakeLists.txt` does `add_subdirectory(../../JUCE JUCE)`, which fails outright on
an empty folder.

## First build

```bash
./utils/build.sh -o GainPlugin
```

The first run is slow: it configures the project and compiles JUCE from source. Later builds are
incremental. You should end up with a window titled *Gain Plugin* passing audio through.

Outputs land in:
- Standalone → `bank/GainPlugin/build/GainPlugin_artefacts/Standalone/`
- VST3 → `~/Library/Audio/Plug-Ins/VST3/` (restart your DAW to see it)

## First validation

```bash
./utils/validate.sh GainPlugin
```

Also slow the first time — it builds pluginval, a whole JUCE application, into a separate
`build-pluginval/` tree (~300 MB). Exit code 0 means every test passed. See
[`pluginval.md`](../tools/pluginval.md).

## Editor setup

For working IntelliSense and no red squiggles under `juce::` symbols, see
[`editor_setup.md`](editor_setup.md). The short version: builds emit
`build/compile_commands.json`, and your editor has to be pointed at it.

## Starting your own plugin

[`starter_template.md`](starter_template.md) walks through copying `example_plugin/` into `bank/`.

---

## Troubleshooting

**`add_subdirectory given source "../../JUCE" which is not an existing directory`**
The submodule isn't checked out. `git submodule update --init`.

**CMake version errors from JUCE**
JUCE 8 needs CMake ≥ 3.22. `brew upgrade cmake`.

**Plugin doesn't appear in the DAW**
VST3s install to `~/Library/Audio/Plug-Ins/VST3/` on build, but most hosts only rescan at startup
or on an explicit rescan. Also check `COPY_PLUGIN_AFTER_BUILD TRUE` is still in the plugin's
`CMakeLists.txt`.

**Undefined symbols after adding a source file**
`target_sources` changed but CMake wasn't re-run. `./utils/build.sh -c <plugin>`.

**Red squiggles on `juce::` in the editor**
`compile_commands.json` is missing or not registered — see
[`editor_setup.md`](editor_setup.md).

**Reclaiming disk space**
Validation trees are ~300 MB per plugin. `rm -rf bank/*/build-pluginval` is always safe; the next
`validate.sh` run rebuilds them.
