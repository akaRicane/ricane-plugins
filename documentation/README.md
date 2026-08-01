# Documentation

Notes written while learning JUCE plugin development. Organised by *what you're trying to do*
rather than by when it was written.

```
documentation/
├── roadmap.md       what's next, what's known-broken, what's landed
├── setup/           get the repo running, set up the editor, start a new plugin
├── knowledge/       audio theory and JUCE learnings — the transferable part
├── plugins/         one page per plugin in bank/
├── utils/           the build/open/validate scripts and the CMake workflow
├── tools/           third-party tooling (currently pluginval)
└── example_plugin/  a copy-me template — code, not prose
```

## Start here

New to the repo? [`setup/installation.md`](setup/installation.md) → build GainPlugin →
[`knowledge/00_plugin_anatomy.md`](knowledge/00_plugin_anatomy.md) to understand what you just
built.

Starting a new plugin? [`setup/starter_template.md`](setup/starter_template.md).

Wondering what's next or what's known-broken? [`roadmap.md`](roadmap.md).

---

## setup/

Getting a working environment.

- [`installation.md`](setup/installation.md) — requirements, cloning with submodules, first build, troubleshooting
- [`editor_setup.md`](setup/editor_setup.md) — clean IntelliSense & formatting (no red squiggles)
- [`starter_template.md`](setup/starter_template.md) — start a new plugin from `example_plugin/`

## knowledge/

The part that transfers to any plugin you write later. Numbered in a sensible reading order.

- [`00_plugin_anatomy.md`](knowledge/00_plugin_anatomy.md) — the five functions that matter in a processor
- [`01_gain.md`](knowledge/01_gain.md) — gain processing (manual and `juce::dsp` versions)
- [`02_panning.md`](knowledge/02_panning.md) — stereo panning and pan laws
- [`03_delay.md`](knowledge/03_delay.md) — delay lines and ring buffers

## plugins/

What's actually in [`bank/`](../bank/), one page each: what it does, why it's built that way, and
what it taught.

- [`gain_plugin.md`](plugins/gain_plugin.md) — decibel volume control, smoothed with `juce::dsp::Gain`
- [`panner_plugin.md`](plugins/panner_plugin.md) — stereo panning, hand-rolled smoothing, and the bus-layout crash it taught us
- [`delay_plugin.md`](plugins/delay_plugin.md) — the first time-based plugin *(scaffolded; DSP not written yet)*

## utils/

How building works, and the scripts that drive it.

- [`scripts.md`](utils/scripts.md) — `build.sh`, `open.sh`, `validate.sh` reference
- [`build_process.md`](utils/build_process.md) — the CMake workflow, every option, and the gotchas

## tools/

Third-party tooling wired into the repo.

- [`pluginval.md`](tools/pluginval.md) — validating a plugin against what a strict host expects

---

## Conventions

- **Prose files are markdown at a folder's root.** `example_plugin/` is the exception: it's a
  buildable plugin, kept here because it belongs with the docs that explain it.
- **Links between docs are relative** so they work on GitHub and in an editor.
- Each `plugins/` page records not just what the plugin does but **what went wrong** while writing
  it. That's usually the part worth re-reading.
