# Roadmap

Where the project is going, and what's already landed. The point of this repo is learning, so
"next" is chosen by *what it teaches*, not by what would make the most useful product.

---

## Next

**Delay plugin.** The natural third plugin, and the first one where a buffer's size depends on the
sample rate. That makes it the first real test of everything set up so far: a delay line sized for
44.1 kHz and then run at 96 kHz is the classic beginner crash, and validation's sample-rate sweep
is built to catch exactly that. Theory notes already exist in
[`knowledge/03_delay.md`](knowledge/03_delay.md).

**[Gin](https://github.com/FigBug/Gin) as a submodule.** FigBug's extra JUCE modules — more DSP and
GUI building blocks than JUCE ships with. Same pattern as `JUCE/` and `tools/pluginval/`: pin it,
clone recursively, and add it per-plugin rather than globally.

---

## Known gaps

Things that are wrong or missing today, written down so they don't get quietly forgotten.

- **PannerPlugin is stereo-only.** It refuses mono-in/stereo-out, which is a common way for a host
  to place a mono source. Supporting it means handling the mono case in `processBlock`, not just
  widening `isBusesLayoutSupported`. See
  [`plugins/panner_plugin.md`](plugins/panner_plugin.md).
- **PannerPlugin uses a simple −6 dB pan law**, so a centred signal is quieter than a hard-panned
  one. Equal-power panning (sin/cos, +3 dB centre) is the usual alternative — see
  [`knowledge/02_panning.md`](knowledge/02_panning.md).
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
