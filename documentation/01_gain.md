# Gain Processing

## Concept
Multiply every sample by a linear factor derived from a dB value.
Output depends only on the current sample — no history needed.

## Key learnings

- **dB to linear**: `linear = 10^(dB/20)` for amplitude. Use `juce::Decibels::decibelsToGain(db)` in real code.
- **Hoist constant computation**: compute `gainLinear` once before the loop, not inside it.
- **Buffer access**: use `buffer.getWritePointer(channel)` — `AudioBuffer` has no `operator[]`.
- **Loop order**: channels outer, samples inner — each channel's data is contiguous in memory.
- **No return**: buffer is passed by reference and modified in-place.
- **ScopedNoDenormals**: always at the top of processBlock.
- **Smoothing**: use `juce::dsp::Gain` which handles dB conversion and zipper-noise ramping internally. Or roll your own one-pole IIR (see panning doc).

## Using juce::dsp::Gain (recommended)

### Header
```cpp
juce::dsp::Gain<float> gain;
```

### prepareToPlay
```cpp
juce::dsp::ProcessSpec spec;
spec.sampleRate       = sampleRate;
spec.maximumBlockSize = (juce::uint32) samplesPerBlock;
spec.numChannels      = (juce::uint32) getTotalNumOutputChannels();
gain.prepare(spec);
gain.setRampDurationSeconds(0.05f); // 50ms smoothing
```

### processBlock
```cpp
juce::ScopedNoDenormals noDenormals;

auto gainDb = apvts.getRawParameterValue("GAIN_DB")->load();
gain.setGainDecibels(gainDb);

juce::dsp::AudioBlock<float> block(buffer);
juce::dsp::ProcessContextReplacing<float> context(block);
gain.process(context);
```

## Manual implementation (for learning)

### processBlock
```cpp
juce::ScopedNoDenormals noDenormals;

const float gainDb     = apvts.getRawParameterValue("GAIN_DB")->load();
const float gainLinear = juce::Decibels::decibelsToGain(gainDb);

for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
{
    auto* data = buffer.getWritePointer(ch);
    for (int i = 0; i < buffer.getNumSamples(); ++i)
        data[i] *= gainLinear;
}
```
