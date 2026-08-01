# GainPlugin

A volume control in decibels, click-free. The first plugin in `bank/`, and the smallest thing
that is still a *complete* plugin: one parameter, state that survives a session reload, a GUI
attached to the parameter, and smoothing so it doesn't click.

| | |
|---|---|
| Folder | [`bank/GainPlugin/`](../../bank/GainPlugin/) |
| Formats | VST3, Standalone (AU too when validating) |
| `PLUGIN_CODE` | `Gain` |
| Parameters | `GAIN_DB` — −60 … +12 dB, 0.1 steps, default 0 |
| Status | Validates clean at strictness 5 and 10 |

## What it does

```cpp
const float gainDb = apvts.getRawParameterValue("GAIN_DB")->load();
gain.setGainDecibels(gainDb);

juce::dsp::AudioBlock<float> block(buffer);
juce::dsp::ProcessContextReplacing<float> context(block);
gain.process(context);
```

That's the whole DSP. The interesting parts are what it *doesn't* do by hand.

### `juce::dsp::Gain` does the smoothing

Setting a raw multiplier per block gives you a **zipper click**: the gain jumps discontinuously at
each block boundary, and a step change in amplitude is a click. `juce::dsp::Gain` ramps between
values instead, over a duration set once in `prepareToPlay`:

```cpp
gain.setRampDurationSeconds(0.05);
```

So `setGainDecibels` per block is safe — the object interpolates the rest.

### dB, not a linear multiplier

The parameter is in decibels because that is how loudness is perceived and how every mixer is
labelled. `−60 … +12` is a normal fader range. `juce::dsp::Gain` converts internally.

### It is channel-agnostic

`AudioBlock` wraps whatever buffer arrives and `gain.process` scales every channel it finds. This
is why GainPlugin survives bus-layout tests that crashed [PannerPlugin](panner_plugin.md) — it
never indexes a channel by number, so a mono or 5.1 buffer is handled just as well as stereo.

Worth understanding as a general principle: **process generically and you inherit correctness for
free; index channels by hand and you owe the host an `isBusesLayoutSupported`.**

## Reading the code

| File | What to look at |
|---|---|
| `src/PluginProcessor.h` | The `AudioProcessor` interface, the `apvts` member, the `juce::dsp::Gain` member |
| `src/PluginProcessor.cpp` | `createParameterLayout`, `prepareToPlay` (ProcessSpec), `processBlock` |
| `src/PluginEditor.cpp` | A slider bound to the parameter with a `SliderAttachment` |

The generic walkthrough of those five functions is in
[`00_plugin_anatomy.md`](../knowledge/00_plugin_anatomy.md); the DSP theory is in
[`01_gain.md`](../knowledge/01_gain.md).

## Build and validate

```bash
./utils/build.sh -o GainPlugin     # build, then open the Standalone
./utils/validate.sh GainPlugin     # check it behaves in a real host
```
