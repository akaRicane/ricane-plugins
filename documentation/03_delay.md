# Delay Line

## Concept
Record incoming samples into a ring buffer. Read them back N samples later.
The output depends on past samples — this is the first **time-based** processor.

## Ring buffer mechanics

- Buffer size: `sampleRate * maxDelaySeconds` samples (per channel)
- One shared `writeHead` index, advances every sample
- `readHead = (writeHead - delaySamples + bufferSize) % bufferSize`
- The `+ bufferSize` before `%` is required — C++ modulo returns negative values for negative operands

## Key learnings

- **Read before write**: read the delayed sample first, then overwrite that position with the current input. If you write first, a zero-delay read returns what you just wrote.
- **Save the dry sample**: modify `data[i]` only after saving the original — the delay buffer must store the unprocessed input.
- **writeHead is shared across channels**: it must advance once per sample, outside the channel loop. Use samples-outer, channels-inner loop order.
- **Allocate in prepareToPlay**: buffer size depends on sample rate, which isn't known until the host calls `prepareToPlay`. Always call `clear()` after allocation — uninitialized memory contains garbage.
- **Wet/dry mix**: `(dry + delayed) / 2` is a 50/50 mix. In a real plugin this would be a parameter.

## Header (private)
```cpp
juce::AudioBuffer<float> delayBuffer;
int writeHead { 0 };
```

## prepareToPlay
```cpp
const float maxDelaySeconds = 1.0f;
const int maxDelaySamples = static_cast<int>(sampleRate * maxDelaySeconds);

delayBuffer.setSize(getTotalNumOutputChannels(), maxDelaySamples);
delayBuffer.clear();
writeHead = 0;
```

## processBlock
```cpp
juce::ScopedNoDenormals noDenormals;

const int delaySamples = static_cast<int>(
    apvts.getRawParameterValue("DELAY_TIME")->load() * sampleRate
);

const int bufferSize = delayBuffer.getNumSamples();

auto* dataL = buffer.getWritePointer(0);
auto* dataR = buffer.getWritePointer(1);

for (int i = 0; i < buffer.getNumSamples(); ++i)
{
    const int readHead = (writeHead - delaySamples + bufferSize) % bufferSize;

    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
    {
        auto* data = buffer.getWritePointer(ch);
        const float dry     = data[i];
        const float delayed = delayBuffer.getSample(ch, readHead);

        data[i] = (dry + delayed) / 2.0f;                  // 50/50 wet/dry
        delayBuffer.setSample(ch, writeHead, dry);          // store dry input
    }

    writeHead = (writeHead + 1) % bufferSize;               // advance once per sample
}
```

## Extension ideas
- Add a **feedback** parameter: feed the output back into the delay buffer instead of the dry signal
- Add a **wet/dry** parameter to control the mix ratio
- Add **delay time smoothing** (one-pole IIR on `delaySamples`) to avoid pitch artifacts when the knob moves
