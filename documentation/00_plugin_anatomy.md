# Plugin Anatomy — PluginProcessor.cpp

## The five functions that matter

### Constructor
Sets up the bus layout (stereo in/out) and initializes `apvts` with the parameter layout.
Called once when the plugin is instantiated.

```cpp
GainAudioProcessor::GainAudioProcessor()
    : AudioProcessor(BusesProperties()
        .withInput ("Input",  juce::AudioChannelSet::stereo(), true)
        .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      apvts(*this, nullptr, "Parameters", createParameterLayout())
{}
```

---

### createParameterLayout()
Declares all knobs/sliders as typed parameter objects. Called once by the constructor.
Each parameter has an ID (used to read it in `processBlock`), a range, and a default value.

```cpp
layout.add(std::make_unique<juce::AudioParameterFloat>(
    juce::ParameterID { "GAIN_DB", 1 },
    "Gain",
    juce::NormalisableRange<float>(-60.0f, 12.0f, 0.1f),
    0.0f
));
```

---

### prepareToPlay(sampleRate, samplesPerBlock)
Called by the host before audio starts, and whenever sample rate or block size changes.
Use it to:
- Allocate buffers that depend on sample rate (delay lines, etc.)
- Initialize DSP objects (`gain.prepare(spec)`)
- Snap smoothed values to their current parameter value (avoid ramp on startup)
- Compute coefficients that depend on sample rate

```cpp
void prepareToPlay(double sampleRate, int samplesPerBlock)
{
    smoothedValue = apvts.getRawParameterValue("PARAM")->load(); // snap, no ramp
    smoothCoeff = 1.0f - std::exp(-1.0f / (sampleRate * smoothingSeconds));
}
```

---

### processBlock(buffer, midiMessages)
The audio loop. Called hundreds of times per second by the host.
`buffer` is an `AudioBuffer<float>` — a 2D array of [channel][sample], passed by reference, modified in-place.

Rules:
- Always start with `juce::ScopedNoDenormals noDenormals;`
- Read parameters via `apvts.getRawParameterValue("ID")->load()` (atomic, thread-safe)
- Hoist all constant computations outside the sample loop
- For shared per-sample state (writeHead, smoothedValue): use samples-outer, channels-inner loop order

```cpp
void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;
    // ... your DSP here
}
```

---

### getStateInformation / setStateInformation
Called by the host to **save** and **restore** the plugin state (session recall, presets).
Not related to live UI interaction. Use `apvts` serialization — it handles all parameters automatically.

```cpp
void getStateInformation(juce::MemoryBlock& destData)
{
    auto state = apvts.copyState();
    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xml(getXmlFromBinary(data, sizeInBytes));
    if (xml != nullptr && xml->hasTagName(apvts.state.getType()))
        apvts.replaceState(juce::ValueTree::fromXml(*xml));
}
```

---

## Key types

| Type | What it is |
|---|---|
| `AudioBuffer<float>` | 2D array of samples [channel][sample], passed by reference |
| `AudioProcessorValueTreeState` (apvts) | Connects UI parameters to the processor, thread-safe |
| `ScopedNoDenormals` | Disables CPU denormal handling for the scope — prevents audio dropouts |
| `juce::dsp::ProcessSpec` | Struct carrying sampleRate, blockSize, numChannels — passed to DSP objects in prepareToPlay |
