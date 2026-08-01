// ─────────────────────────────────────────────────────────────────────────────
// PluginProcessor.cpp — defines the functions declared in PluginProcessor.h.
// `DelayAudioProcessor::foo` means "foo belonging to DelayAudioProcessor".
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginProcessor.h"
#include "PluginEditor.h" // Needed because createEditor() below builds an editor.

// Constructor. The part after ':' is the MEMBER-INITIALIZER LIST — it runs before
// the {} body and initializes the base class and members.
DelayAudioProcessor::DelayAudioProcessor()
    // Tell the base AudioProcessor our bus layout: one stereo in, one stereo out.
    : juce::AudioProcessor(
          juce::AudioProcessor::BusesProperties()
              .withInput("Input", juce::AudioChannelSet::stereo(), true)
              .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      // Build the parameter tree: (this processor, no undo manager, tree name, params).
      apvts(*this, nullptr, "Parameters", createParameterLayout()) {}

// Declares every parameter the plugin exposes. Called once, from the constructor.
juce::AudioProcessorValueTreeState::ParameterLayout DelayAudioProcessor::createParameterLayout() {
  juce::AudioProcessorValueTreeState::ParameterLayout layout;

  //   ParameterID{"ID", 1} : the string ID you read in processBlock + a version hint.
  //   "Param Name"         : shown in the host.
  //   NormalisableRange    : min, max, step.
  //   last float           : default value.

  // The upper bound is maxDelaySeconds, NOT a hand-typed number: the ring buffer is
  // only that long, so a bigger range would let the user ask to read past its end.
  layout.add(std::make_unique<juce::AudioParameterFloat>(
      juce::ParameterID{"DELAY_TIME", 1}, "Delay time",
      juce::NormalisableRange<float>(0.0f, maxDelaySeconds, 0.01f), 0.25f));

  // 0 = only the input, 1 = only the echo. Defaulting to fully wet would make the
  // plugin sound broken on load, so start halfway.
  layout.add(std::make_unique<juce::AudioParameterFloat>(
      juce::ParameterID{"DRY_WET", 2}, "Dry / Wet", juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f), 0.5f));

  return layout;
}

// Called before playback. Prepare anything that depends on sample rate / block size.
void DelayAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
  currentSampleRate = sampleRate;

  // Seconds -> samples is the one conversion that depends on the sample rate, which
  // is exactly why the buffer is sized here and not in the constructor: at 96 kHz
  // two seconds needs twice the memory it does at 48 kHz.
  const int maxDelaySamples = static_cast<int>(sampleRate * maxDelaySeconds) + 1;

  // Size for whichever bus is wider, so the channel loop in processBlock can never
  // index a channel the delay buffer doesn't have.
  const int numChannels = juce::jmax(getTotalNumInputChannels(), getTotalNumOutputChannels());

  // setSize allocates — fine here (the message thread), forbidden in processBlock.
  delayBuffer.setSize(numChannels, maxDelaySamples);
  delayBuffer.clear(); // Fresh memory holds garbage; uncleared, it bursts on the first block.
  writeHead = 0;

  // The ramp is specified in SECONDS, so it needs the sample rate to know how many
  // steps that is — another thing that can only be set up here.
  smoothedDelaySamples.reset(sampleRate, delaySmoothingSeconds);

  // setCurrentAndTargetValue, NOT setTargetValue: on load we want the saved delay
  // time immediately. Starting at 0 and gliding would make every session recall
  // open with an audible swoop.
  const float initialDelay = apvts.getRawParameterValue("DELAY_TIME")->load() * static_cast<float>(sampleRate);
  smoothedDelaySamples.setCurrentAndTargetValue(initialDelay);

  juce::ignoreUnused(samplesPerBlock); // Silence "unused" warnings for now.
}

// The host proposes a layout; we say yes or no. JUCE's default says yes to
// everything, which is how you end up handed a mono buffer and reading off the end.
// We accept only mono->mono and stereo->stereo: in must equal out, because the delay
// is one independent ring buffer per channel with no up/down-mixing.
bool DelayAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const {
  const auto& out = layouts.getMainOutputChannelSet();

  if (out != juce::AudioChannelSet::mono() && out != juce::AudioChannelSet::stereo())
    return false;

  return layouts.getMainInputChannelSet() == out;
}

// The audio callback. `buffer` already holds the INPUT samples; edit it in place.
void DelayAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) {
  juce::ScopedNoDenormals noDenormals; // Disable CPU denormals for this scope (always do this).

  // The ring buffer's own length is what we wrap around — NOT the host's block size.
  // Those are unrelated numbers: the block is a few hundred samples, the ring is
  // seconds long. Wrapping on the block size would have thrown away nearly all of it.
  const int ringLength = delayBuffer.getNumSamples();
  if (ringLength == 0) // prepareToPlay hasn't run yet — nothing sane to do.
    return;

  // Read the parameters once per block, not per sample: they're atomics, and the
  // user can't move a knob fast enough for the difference to be audible.
  const float delaySeconds = apvts.getRawParameterValue("DELAY_TIME")->load();
  const float dryWetCoef = apvts.getRawParameterValue("DRY_WET")->load();

  // Seconds -> samples, then clamped into the range the ring buffer can actually
  // serve. The parameter range already guarantees this, but a clamp is cheap and
  // means a later range change can't silently turn into an out-of-bounds read.
  // The floor is 1, not 0: at less than one sample of delay the interpolation below
  // would blend in delayBuffer[writeHead], which we haven't written this pass — it
  // still holds whatever was there a whole ring ago.
  const float targetDelaySamples = juce::jlimit(
      1.0f, static_cast<float>(ringLength - 1), delaySeconds * static_cast<float>(currentSampleRate));

  // We only set the TARGET here. The value itself moves one step per sample inside
  // the loop, so the read head slides to its new position instead of teleporting.
  smoothedDelaySamples.setTargetValue(targetDelaySamples);

  // Only touch channels that exist in BOTH buffers.
  const int numChannels = juce::jmin(buffer.getNumChannels(), delayBuffer.getNumChannels());

  for (int i = 0; i < buffer.getNumSamples(); ++i) {
    // ONE step per sample, and outside the channel loop — calling it per channel
    // would advance the ramp twice as fast in stereo and desync the channels.
    const float delaySamples = smoothedDelaySamples.getNextValue();

    // Walk backwards from the write head, wrapping past 0. A single `if` suffices
    // because delaySamples never exceeds ringLength - 1, so we can only ever
    // undershoot zero once. (Note we can't use % here any more: readPos is a float,
    // and C++'s % is integers only.)
    float readPos = static_cast<float>(writeHead) - delaySamples;
    if (readPos < 0.0f)
      readPos += static_cast<float>(ringLength);

    // The read head now lands BETWEEN two stored samples. Take the pair either side
    // of it and blend them by how far along we are — linear interpolation. Without
    // this the position would snap to whole samples and re-introduce the zipper.
    const int index0 = static_cast<int>(readPos);
    const int index1 = (index0 + 1) % ringLength; // May wrap past the end of the ring.
    const float frac = readPos - static_cast<float>(index0);

    for (int ch = 0; ch < numChannels; ++ch) {
      auto* data = buffer.getWritePointer(ch);
      const float dry = data[i];

      // sample0 + frac*(sample1 - sample0): at frac 0 it's purely sample0, at frac
      // approaching 1 purely sample1, and it moves continuously in between.
      const float sample0 = delayBuffer.getSample(ch, index0);
      const float sample1 = delayBuffer.getSample(ch, index1);
      const float delayed = sample0 + frac * (sample1 - sample0);

      // Crossfade between the two. Watch the sign:
      //   dry*(1-coef) + delayed*coef  =  dry - dry*coef + delayed*coef
      //                                =  dry + coef*(delayed - dry)
      // The bracket is a DIFFERENCE, not a sum. With a sum, coef=0 wouldn't give
      // you the dry signal back — it would invert and double it.
      data[i] = dry + dryWetCoef * (delayed - dry);

      // Store the DRY input, so the ring holds the original signal. (Storing the
      // mixed output instead is how you'd build feedback — see the docs.)
      delayBuffer.setSample(ch, writeHead, dry);
    }

    // One step per SAMPLE, outside the channel loop — every channel shares the head.
    writeHead = (writeHead + 1) % ringLength;
  }
}

// The host calls this to create the plugin's window. `*this` lets the editor talk back.
juce::AudioProcessorEditor* DelayAudioProcessor::createEditor() { return new DelayAudioProcessorEditor(*this); }

// Save: serialize the whole parameter tree to the host's memory block (XML -> binary).
void DelayAudioProcessor::getStateInformation(juce::MemoryBlock& destData) {
  if (auto xml = apvts.copyState().createXml())
    copyXmlToBinary(*xml, destData);
}

// Restore: the reverse. Only replace state if the saved data matches our tree type.
void DelayAudioProcessor::setStateInformation(const void* data, int sizeInBytes) {
  if (auto xml = getXmlFromBinary(data, sizeInBytes))
    if (xml->hasTagName(apvts.state.getType()))
      apvts.replaceState(juce::ValueTree::fromXml(*xml));
}

// JUCE's entry point: a free function (not a class member) the host calls to create
// the plugin. This is WHY the constructor must be public.
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() { return new DelayAudioProcessor(); }
