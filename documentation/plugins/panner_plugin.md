# PannerPlugin

Places a signal left or right by attenuating one side against the other. Takes mono or stereo in
and always produces stereo. The second plugin in `bank/`, and the first one to process channels
*individually* — which is where it got interesting.

| | |
|---|---|
| Folder | [`bank/PannerPlugin/`](../../bank/PannerPlugin/) |
| Formats | VST3, Standalone (AU too when validating) |
| `PLUGIN_CODE` | `Pann` |
| Parameters | `PAN` — −1.0 (hard left) … +1.0 (hard right), 0.01 steps, default 0 |
| Layouts | Mono **or** stereo in, stereo out — see below |
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

The fix is to say what it actually supports. The constraint belongs on the **output**: panning
distributes a signal across two speakers, so two channels out is non-negotiable, while the input
can be either.

```cpp
bool PannerAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const auto mono   = juce::AudioChannelSet::mono();
    const auto stereo = juce::AudioChannelSet::stereo();

    if (layouts.getMainOutputChannelSet() != stereo)
        return false;                       // Nowhere to pan to.

    const auto in = layouts.getMainInputChannelSet();
    return in == mono || in == stereo;
}
```

## Mono input: the buffer lies about its channel count

Accepting mono-in/stereo-out is only half the job — `processBlock` has to handle it, and the trap
is subtle:

> **`buffer.getNumChannels()` is how many channels the buffer HAS, not how many contain input.**

JUCE sizes the buffer by the **wider** of the two buses. With mono in and stereo out you get a
**two-channel** buffer where only channel 0 was filled — channel 1 holds whatever was in that
memory last block. So `if (buffer.getNumChannels() == 1)` never fires in the case you wrote it for.
The question to ask is `getMainBusNumInputChannels()`.

Then duplicate the input across both channels before panning:

```cpp
if (getMainBusNumInputChannels() == 1)
    buffer.copyFrom (1, 0, buffer, 0, 0, buffer.getNumSamples());
```

**Copy — don't alias the pointer.** `dataR = dataL` looks like a free way to handle mono and is
badly wrong: both pointers reference the same samples, so the loop applies *both* gains to them
(`leftGain * rightGain`). Centre gives 0.25 instead of 0.5, and at hard left `rightGain` is 0.0, so
the plugin goes **completely silent** exactly when it should be loudest on one side. `copyFrom` is
a memcpy, not an allocation, so it's safe on the audio thread.

pluginval went from a segfault to `Layouts tested: 5, accepted by setBusesLayout: 2`.

**The lesson:** if `processBlock` indexes a channel by number, you owe the host an
`isBusesLayoutSupported`. And note this misbehaved in *no* Standalone build ever — the Standalone
always supplies stereo, which is exactly why it went unnoticed. Full write-up in
[`pluginval.md`](../tools/pluginval.md).

## Known limitations

- **Stereo in is treated as balance, not true panning.** With two real input channels the plugin
  just attenuates each side, so panning right turns the left channel down rather than *moving* the
  left-channel content rightward. That's what most "pan" controls on a stereo track do, but a true
  stereo panner would collapse and re-place the image.
- **Simple −6 dB pan law.** Centre gives `0.5`/`0.5`, so a centred signal is quieter than the same
  signal panned hard to one side. That's a design choice rather than a bug; equal-power panning
  uses a sin/cos law and a +3 dB centre boost instead — see
  [`02_panning.md`](../knowledge/02_panning.md).

## Build and validate

```bash
./utils/build.sh -o PannerPlugin
./utils/validate.sh PannerPlugin
```
