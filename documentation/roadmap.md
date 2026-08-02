# Roadmap

Where the project is going, and what's already landed. The point of this repo is learning, so
"next" is chosen by *what it teaches*, not by what would make the most useful product.

---

## In progress

**DelayPlugin — write the DSP.** Scaffolded with `./utils/new_plugin.sh` and currently a
passthrough: it builds and loads, but has no parameters and an empty `processBlock`. The theory
and a reference implementation are in [`knowledge/03_delay.md`](knowledge/03_delay.md); the traps
specific to this one are listed in [`plugins/delay_plugin.md`](plugins/delay_plugin.md).

This is the first plugin whose state must be sized from the sample rate, which makes it the first
real test of everything set up so far — a delay line sized for 44.1 kHz and then run at 96 kHz is
the classic beginner crash, and validation's sample-rate sweep is built to catch exactly that.

## Next

**[Gin](https://github.com/FigBug/Gin) as a submodule.** FigBug's extra JUCE modules — more DSP and
GUI building blocks than JUCE ships with. Same pattern as `JUCE/` and `tools/pluginval/`: pin it,
clone recursively, and add it per-plugin rather than globally.

---

## Known gaps

Things that are wrong or missing today, written down so they don't get quietly forgotten.

- **PannerPlugin treats stereo input as balance, not true panning.** It attenuates each side rather
  than moving the stereo image, so panning right turns the left channel down instead of relocating
  its content. Fine for a channel-strip pan control; not a true stereo panner. See
  [`plugins/panner_plugin.md`](plugins/panner_plugin.md).
- **PannerPlugin uses a simple −6 dB pan law**, so a centred signal is quieter than a hard-panned
  one. Equal-power panning (sin/cos, +3 dB centre) is the usual alternative — see
  [`knowledge/02_panning.md`](knowledge/02_panning.md).
- **DelayPlugin has no feedback.** It's a single-tap delay — exactly one echo. Storing the mixed
  output in the ring buffer instead of the dry input is the whole change; see
  [`plugins/delay_plugin.md`](plugins/delay_plugin.md).
- **DelayPlugin's delay-time smoothing is tape-style, and that's a choice, not a default.** The
  read head glides to its new position, so large jumps pitch-bend audibly. A dual-read-head
  crossfade would retime without the bend, at the cost of two reads per sample.
- **`./utils/validate.sh -r enabled` fails on every plugin here,** GainPlugin included. It's a
  `calloc` from lazy thread-local init inside JUCE's own VST3 parameter path, not our code —
  `-r relaxed` is the gate that means something. Detail in
  [`tools/pluginval.md`](tools/pluginval.md).
- **A parameter-ID typo is only caught at runtime.** `SliderAttachment` looks parameters up by
  string, so misspelling one in the editor compiles cleanly and asserts when the window opens.
  This already cost time in DelayPlugin (`"WET_DRY"` vs `"DRY_WET"`). Shared `constexpr` ID
  constants per plugin would make it a compile error.
- **The Steinberg VST3 validator is disabled** in `cmake/Pluginval.cmake`, because enabling it
  makes CMake fetch and build the entire VST3 SDK. Turning it on would add spec-conformance
  checks on top of what pluginval already does.
- **Validation is macOS-only in practice.** `--rtcheck` is macOS/Linux only, and the scripts use
  `open`/`killall`/`.app` bundles throughout.

---

## Ideas, not commitments

- Run validation in CI on push. pluginval exits 0/1 and has `--skip-gui-tests` for headless
  machines, so the mechanism is already there; the question is whether the ~300 MB build is worth
  it for a learning repo.
- A shared DSP library in `bank/`, once two plugins genuinely need the same code. Not before —
  the independence of each plugin is deliberate.
- Presets beyond the parameter-tree state that already round-trips.

---

## Done

**2026-08-01**

- **`utils/new_plugin.sh`** — scaffolds a plugin from `example_plugin/`: renames every identifier
  to the `<Prefix>AudioProcessor` convention the rest of `bank/` uses, enforces a unique
  `PLUGIN_CODE`, and registers the build with the editor. **DelayPlugin** was created with it.
- **Documentation reorganised** into `setup/` · `knowledge/` · `plugins/` · `utils/` · `tools/`,
  with a single index at [`README.md`](README.md). Added installation, per-plugin and script
  reference pages.
- **[pluginval](https://github.com/Tracktion/pluginval) wired into every plugin**, behind
  `-DENABLE_PLUGINVAL=ON` and driven by `./utils/validate.sh`. Off by default because it builds a
  whole JUCE app per plugin. Guide in [`tools/pluginval.md`](tools/pluginval.md).
- **PannerPlugin bus-layout crash fixed.** It inherited JUCE's default
  `isBusesLayoutSupported` (`return true`) while indexing channel 1 unconditionally, so a mono
  buffer read off the end. pluginval segfaulted on it the first time it ran — the first bug this
  tooling caught. Its `PLUGIN_CODE` was also still the template's `Newp`, colliding with
  `example_plugin`.
- **Scripts moved into `utils/`** — `build.sh`, `open.sh`, and the new `validate.sh`.
- **JUCE converted to a git submodule**, pinned to the `8.0.13` tag. It had been a shallow clone
  of `master` with no tags fetched, so "8.0.13" was only the version string on a post-release
  commit, not the release itself.
- **PannerPlugin** added — first use of `example_plugin/` as a real template.

**2026-07-29**

- Annotated `example_plugin/` template, compiler warnings cleaned up, editor/formatting setup,
  README and license.

**Earlier**

- **GainPlugin** — the first plugin, and the reference for what a complete one looks like.
