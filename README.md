# Plugins

A personal **bank of audio plugins** built with the [JUCE](https://juce.com) framework,
written to learn plugin development from the ground up — clean, step by step, one
self-contained plugin at a time.

Built and maintained by **Ricane**.

## What's inside

```
plugins/
├── bank/                # the plugins (each self-contained, its own CMakeLists)
│   ├── GainPlugin/       # a smoothed gain: parameter + apvts + juce::dsp::Gain
│   └── PannerPlugin/     # stereo panning
├── documentation/       # readable notes + a copy-me example_plugin/ template
├── utils/               # the scripts
│   ├── build.sh          # build a plugin (interactive menu or by name)
│   ├── open.sh           # launch a built Standalone app
│   └── validate.sh       # run pluginval against a plugin
├── cmake/               # shared CMake modules (currently the pluginval glue)
├── tools/pluginval/     # plugin validator (submodule, opt-in) — see Validating below
├── JUCE/                # the JUCE framework (submodule, pinned to 8.0.13) — see note below
├── LICENSE              # MIT
└── README.md
```

Each plugin in `bank/` is **independent**: it has its own `CMakeLists.txt` that pulls JUCE
in directly, so plugins never depend on each other and can be built in isolation.

## Requirements

- **macOS** with the Xcode command-line tools (a C++17 compiler)
- **CMake** ≥ 3.22
- **JUCE 8** — a git submodule in `JUCE/`, pinned to the `8.0.13` tag

## Getting the code

`JUCE/` is a submodule, so clone recursively:

```bash
git clone --recursive https://github.com/<you>/plugins.git
```

Already cloned without `--recursive`? Fetch it after the fact:

```bash
git submodule update --init
```

Nothing in `bank/` will configure until `JUCE/` is populated — every plugin's
`CMakeLists.txt` does `add_subdirectory(../../JUCE JUCE)`.

## Building

The quickest way is the included helper:

```bash
./utils/build.sh                 # interactive: pick a plugin from a menu
./utils/build.sh GainPlugin      # build a specific plugin
./utils/build.sh -o GainPlugin   # build, then open the Standalone app
./utils/build.sh --help          # all options
```

To launch a Standalone you've already built, without rebuilding:

```bash
./utils/open.sh GainPlugin       # quit any stale instance, then launch
./utils/open.sh -t GainPlugin    # run in this terminal, so DBG()/stdout is visible
./utils/open.sh -q GainPlugin    # just quit a running instance
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

## Validating

[pluginval](https://github.com/Tracktion/pluginval) (submodule in `tools/pluginval/`) loads a
built plugin and abuses it the way a strict host would: many sample-rate × block-size
combinations, parameter fuzzing, state save/restore round-trips, editor open/close. Its
`--rtcheck` mode also catches **allocations and locks on the audio thread**.

```bash
./utils/validate.sh                     # interactive: pick a plugin from a menu
./utils/validate.sh GainPlugin          # validate one plugin at strictness 5
./utils/validate.sh -s 10 GainPlugin    # maximum strictness
./utils/validate.sh --help              # every option
```

Exit code 0 means every test passed — trust that over skim-reading the log.

Validation is **off by default**: the first run on a plugin configures a separate
`build-pluginval/` tree and builds pluginval itself (a whole JUCE app, ~280 MB and several
minutes). Your normal `build/` tree is untouched, so everyday builds stay fast.

The full guide — what each test group means, strictness levels, the audio-thread rules
`--rtcheck` enforces, and how to debug a failure — is in
[`documentation/testing_with_pluginval.md`](documentation/testing_with_pluginval.md).

> pluginval is **GPLv3**, unlike this repo's MIT code. Fine for local validation; never ship a
> binary that combines the two.

## Plugins

| Plugin | What it does |
|---|---|
| **GainPlugin** | Volume control in decibels, click-free thanks to `juce::dsp::Gain` smoothing. VST3 + Standalone. |

## TODO / Roadmap

- [x] Add **JUCE** as a git submodule — pinned to the `8.0.13` tag, so the repo is
      self-contained via `git clone --recursive`.
- [ ] Add **[Gin](https://github.com/FigBug/Gin)** (FigBug's extra JUCE modules) as a submodule,
      for additional DSP/GUI building blocks to use in plugins.
- [x] Add **[pluginval](https://github.com/Tracktion/pluginval)** as a submodule, wired into every
      plugin behind `-DENABLE_PLUGINVAL=ON` and driven by `./utils/validate.sh`.
      See *Validating* above.
- [x] Next plugin: **Panning** — first real use of `documentation/example_plugin/`.
- [ ] Next plugin: **Delay** — the first one where the sample-rate sweep in validation really
      earns its keep (a delay buffer sized for one rate and used at another is the classic crash).

## Documentation

- [`00_plugin_anatomy.md`](documentation/00_plugin_anatomy.md) — the five functions that matter in a processor
- [`01_gain.md`](documentation/01_gain.md) — gain processing (manual and `juce::dsp` versions)
- [`02_panning.md`](documentation/02_panning.md) — stereo panning
- [`03_delay.md`](documentation/03_delay.md) — delay line basics
- [`build_process.md`](documentation/build_process.md) — CMake build workflow & reference
- [`testing_with_pluginval.md`](documentation/testing_with_pluginval.md) — validating a plugin against what a strict host expects
- [`editor_setup.md`](documentation/editor_setup.md) — clean IntelliSense & formatting (no red squiggles)
- [`starter_template.md`](documentation/starter_template.md) — start a new plugin from `example_plugin/`

## License

This project's code is released under the **MIT License** — you're free to use, modify, and
distribute it, **as long as you keep the copyright notice** (credit to Ricane). See
[`LICENSE`](LICENSE).

> **Note on JUCE:** the framework in `JUCE/` is a submodule and is **not** covered by this
> license. JUCE has its own licensing terms (see [`JUCE/LICENSE.md`](JUCE/LICENSE.md)). The MIT
> license here applies only to the plugin code in `bank/` and the docs — not to JUCE itself.
