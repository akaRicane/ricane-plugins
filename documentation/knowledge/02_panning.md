# Panning

## Concept
Apply different gain multipliers to left (ch 0) and right (ch 1) channels.
Pan range: -1.0 (hard left) to +1.0 (hard right).

## Pan law (simple -6dB)

| Pan | Left gain | Right gain |
|---|---|---|
| -1.0 | 1.0 | 0.0 |
|  0.0 | 0.5 | 0.5 |
| +1.0 | 0.0 | 1.0 |

```
leftGain  = (1 - pan) / 2
rightGain = (1 + pan) / 2
```

Center is -6dB (both channels at 0.5). This is the simplest pan law — other DAWs add a +3dB center boost for equal-power panning (uses sin/cos), but this is the starting point.

## Key learnings

- **Pan law**: center is quieter than hard pan positions — this is a design choice, not a bug.
- **float `!=` is safe here**: comparing a stored float to the same atomic load (no arithmetic between assignments) — no drift possible.
- **Hoist gains outside the loop**: `leftGain` and `rightGain` are constant per block.
- **Per-sample smoothing**: to avoid clicks on fast knob moves, update `smoothedPan` inside the sample loop using a one-pole IIR filter.
- **One-pole IIR**: `smoothed += (target - smoothed) * coeff` — exponential approach, O(1) memory.
- **Coefficient depends on sample rate**: compute in `prepareToPlay`, not hardcoded.
- **Snap on startup**: initialize `smoothedPan` to the actual parameter value in `prepareToPlay` to avoid a ramp from zero on session load.
- **Loop order for shared state**: samples outer, channels inner — so `smoothedPan` advances once per sample across both channels.
- **Constrain the OUTPUT, not the input**: panning distributes a signal across two speakers, so two channels out is required; mono in is fine and is the classic use case.
- **`buffer.getNumChannels()` ≠ number of input channels**: JUCE sizes the buffer by the *wider* bus. Mono-in/stereo-out gives a 2-channel buffer with only channel 0 filled — channel 1 is stale memory. Ask `getMainBusNumInputChannels()` instead.
- **Duplicate mono input, never alias the pointer**: `dataR = dataL` applies both gains to the same samples (`leftGain * rightGain`), which silences the plugin at hard left/right. Use `buffer.copyFrom(1, 0, buffer, 0, 0, n)` — a memcpy, safe on the audio thread.

## Header (private)
```cpp
float smoothedPan  { 0.0f }; // overwritten in prepareToPlay
float smoothCoeff  { 0.0f };
```

## prepareToPlay
```cpp
smoothedPan = apvts.getRawParameterValue("PAN")->load(); // snap, no ramp
const float smoothingSeconds = 0.05f;
smoothCoeff = 1.0f - std::exp(-1.0f / (sampleRate * smoothingSeconds));
```

## processBlock
```cpp
juce::ScopedNoDenormals noDenormals;

const float pan = apvts.getRawParameterValue("PAN")->load();

auto* dataL = buffer.getWritePointer(0);
auto* dataR = buffer.getWritePointer(1);

for (int i = 0; i < buffer.getNumSamples(); ++i)
{
    smoothedPan += (pan - smoothedPan) * smoothCoeff;

    const float leftGain  = (1.0f - smoothedPan) / 2.0f;
    const float rightGain = (1.0f + smoothedPan) / 2.0f;

    dataL[i] *= leftGain;
    dataR[i] *= rightGain;
}
```
