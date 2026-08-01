# PannerPlugin

Moves a stereo signal left or right by attenuating one side against the other. The second plugin
in `bank/`, and the first one to process channels *individually* — which is where it got
interesting.

| | |
|---|---|
| Folder | [`bank/PannerPlugin/`](../../bank/PannerPlugin/) |
| Formats | VST3, Standalone (AU too when validating) |
| `PLUGIN_CODE` | `Pann` |
| Parameters | `PAN` — −1.0 (hard left) … +1.0 (hard right), 0.01 steps, default 0 |
| Layouts | Stereo in / stereo out only — see below |
| Status | Validates clean at strictness 5 |

## What it does

```cpp
smoothedPan += (pan - smoothedPan) * smoothCoeff;

const float leftGain  = (1.0f - smoothedPan) / 2.0f;
const float rightGain = (1.0f + smoothedPan) / 2.0f;

dataL[i] *= leftGain;
dataR[i] *= rightGain;
```

At `pan = 0` both gains are `0.5`. At `pan = -1` the left channel gets `1.0` and the right `0.0`.

### Hand-rolled smoothing

Unlike [GainPlugin](gain_plugin.md), which hands smoothing to `juce::dsp::Gain`, this one does it
per sample with a one-pole filter:

```cpp
smoothCoeff = 1.0f - std::exp(-1.0f / (sampleRate * smoothingSeconds));
```

The coefficient is recomputed in `prepareToPlay` because it **depends on the sample rate** — the
same 50 ms of smoothing needs a different per-sample step at 44.1 kHz and 96 kHz. Getting this
wrong is a classic bug: the plugin would smooth over the wrong duration whenever the host changed
rate, and you would probably never notice by ear.

`prepareToPlay` also snaps `smoothedPan` to the current parameter value rather than ramping from
zero, so the plugin doesn't sweep across the stereo field every time playback starts.

## The bug it taught us

This plugin **segfaulted the first time it was validated**:

```
Starting tests in: pluginval / Bus layout processing...
pluginval received Segmentation fault: 11, exiting immediately
```

It never implemented `isBusesLayoutSupported`, so it inherited JUCE's default — `return true`,
meaning "every layout is fine". Meanwhile `processBlock` calls `buffer.getWritePointer(1)`
unconditionally. A host that takes the plugin at its word and supplies a **mono** buffer makes
that read run off the end.

The fix is to say what it actually supports:

```cpp
bool PannerAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const auto stereo = juce::AudioChannelSet::stereo();
    return layouts.getMainInputChannelSet()  == stereo
        && layouts.getMainOutputChannelSet() == stereo;
}
```

pluginval went from a segfault to `Layouts tested: 5, accepted by setBusesLayout: 2`.

**The lesson:** if `processBlock` indexes a channel by number, you owe the host an
`isBusesLayoutSupported`. And note this misbehaved in *no* Standalone build ever — the Standalone
always supplies stereo, which is exactly why it went unnoticed. Full write-up in
[`pluginval.md`](../tools/pluginval.md).

## Known limitations

- **Stereo only.** A host wanting mono-in/stereo-out (a common way to place a mono source) is
  refused rather than served. Supporting it means handling the mono case in `processBlock`, not
  just widening the layout check.
- **Simple −6 dB pan law.** Centre gives `0.5`/`0.5`, so a centred signal is quieter than the same
  signal panned hard to one side. That's a design choice rather than a bug; equal-power panning
  uses a sin/cos law and a +3 dB centre boost instead — see
  [`02_panning.md`](../knowledge/02_panning.md).

## Build and validate

```bash
./utils/build.sh -o PannerPlugin
./utils/validate.sh PannerPlugin
```
