# Plugins

A personal **bank of audio plugins** built with the [JUCE](https://juce.com) framework,
written to learn plugin development from the ground up — clean, step by step, one
self-contained plugin at a time.

Built and maintained by **Ricane**.

## What's inside

```
plugins/
├── bank/                # the plugins (each self-contained, its own CMakeLists)
│   └── GainPlugin/       # a smoothed gain: parameter + apvts + juce::dsp::Gain
├── documentation/       # readable notes on concepts & workflow
├── JUCE/                # the JUCE framework (V8)  — see note below
├── build.sh             # build helper (interactive menu or by name)
├── LICENSE              # MIT
└── README.md
```

Each plugin in `bank/` is **independent**: it has its own `CMakeLists.txt` that pulls JUCE
in directly, so plugins never depend on each other and can be built in isolation.

## Requirements

- **macOS** with the Xcode command-line tools (a C++17 compiler)
- **CMake** ≥ 3.22
- **JUCE 8** — vendored in `JUCE/` (see the JUCE note under *License*)

## Building

The quickest way is the included helper:

```bash
./build.sh                 # interactive: pick a plugin from a menu
./build.sh GainPlugin      # build a specific plugin
./build.sh -o GainPlugin   # build, then open the Standalone app
./build.sh --help          # all options
```

Or drive CMake directly from a plugin folder:

```bash
cd bank/GainPlugin
cmake -B build -S .        # configure (first time only)
cmake --build build        # build (after every edit)
```

Outputs:
- **Standalone** app → `bank/<plugin>/build/<Target>_artefacts/Standalone/`
- **VST3** → auto-installed to `~/Library/Audio/Plug-Ins/VST3/` (then restart your DAW)

Full details, including every CMake option and common gotchas, are in
[`documentation/build_process.md`](documentation/build_process.md).

## Plugins

| Plugin | What it does |
|---|---|
| **GainPlugin** | Volume control in decibels, click-free thanks to `juce::dsp::Gain` smoothing. VST3 + Standalone. |

## Documentation

- [`00_plugin_anatomy.md`](documentation/00_plugin_anatomy.md) — the five functions that matter in a processor
- [`01_gain.md`](documentation/01_gain.md) — gain processing (manual and `juce::dsp` versions)
- [`02_panning.md`](documentation/02_panning.md) — stereo panning
- [`03_delay.md`](documentation/03_delay.md) — delay line basics
- [`build_process.md`](documentation/build_process.md) — CMake build workflow & reference

## License

This project's code is released under the **MIT License** — you're free to use, modify, and
distribute it, **as long as you keep the copyright notice** (credit to Ricane). See
[`LICENSE`](LICENSE).

> **Note on JUCE:** the framework in `JUCE/` is **not** covered by this license. JUCE has its
> own licensing terms (see [`JUCE/LICENSE.md`](JUCE/LICENSE.md)). The MIT license here applies
> only to the plugin code in `bank/` and the docs — not to JUCE itself.
