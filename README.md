# Plugins

A personal **bank of audio plugins** built with the [JUCE](https://juce.com) framework,
written to learn plugin development from the ground up — clean, step by step, one
self-contained plugin at a time.

Built and maintained by **Ricane**.

## What's inside

```
plugins/
├── bank/                # the plugins — each self-contained, its own CMakeLists
├── documentation/       # the notes: setup, theory, per-plugin, tooling
├── utils/               # build.sh, open.sh, validate.sh
├── cmake/               # shared CMake modules
├── tools/               # third-party tooling (pluginval)
└── JUCE/                # the framework, pinned to 8.0.13
```

Every plugin in `bank/` is **independent**: its own `CMakeLists.txt` pulls JUCE in directly, so
plugins never depend on each other and can be built in isolation. `JUCE/` and `tools/pluginval/`
are git submodules.

## Quick start

```bash
git clone --recursive <repo-url> plugins && cd plugins
./utils/build.sh -o GainPlugin      # build it, open the Standalone
./utils/validate.sh GainPlugin      # check it behaves in a real host
```

Requirements, editor setup and troubleshooting are in
[`documentation/setup/installation.md`](documentation/setup/installation.md).

## Plugins

| Plugin | What it does |
|---|---|
| **[GainPlugin](documentation/plugins/gain_plugin.md)** | Volume control in decibels, click-free thanks to `juce::dsp::Gain` smoothing |
| **[PannerPlugin](documentation/plugins/panner_plugin.md)** | Stereo panning with a −6 dB pan law and per-sample smoothing |

## Documentation

Everything lives in **[`documentation/`](documentation/README.md)** — setup guides, audio theory
and JUCE learnings, a page per plugin, the build scripts, and tooling.

New here? [Installation](documentation/setup/installation.md) → build GainPlugin →
[Plugin anatomy](documentation/knowledge/00_plugin_anatomy.md).

## Roadmap

Next up is a **Delay** plugin, then [Gin](https://github.com/FigBug/Gin) as a submodule. What's
planned, what's known-broken, and what's already landed:
[`documentation/roadmap.md`](documentation/roadmap.md).

## License

This project's code is released under the **MIT License** — you're free to use, modify, and
distribute it, **as long as you keep the copyright notice** (credit to Ricane). See
[`LICENSE`](LICENSE).

> **Note on JUCE:** the framework in `JUCE/` is a submodule and is **not** covered by this
> license — it has its own terms (see [`JUCE/LICENSE.md`](JUCE/LICENSE.md)). Likewise
> `tools/pluginval/` is **GPLv3**. The MIT license here applies only to the plugin code in
> `bank/`, the scripts, and the docs.
