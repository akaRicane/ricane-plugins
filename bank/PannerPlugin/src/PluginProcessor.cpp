// ─────────────────────────────────────────────────────────────────────────────
// PluginProcessor.cpp — defines the functions declared in PluginProcessor.h.
// `PannerAudioProcessor::foo` means "foo belonging to PannerAudioProcessor".
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginProcessor.h"
#include "PluginEditor.h" // Needed because createEditor() below builds an editor.

// Constructor. The part after ':' is the MEMBER-INITIALIZER LIST — it runs before
// the {} body and initializes the base class and members.
PannerAudioProcessor::PannerAudioProcessor()
    // Tell the base AudioProcessor our bus layout: one stereo in, one stereo out.
    : juce::AudioProcessor(
          juce::AudioProcessor::BusesProperties()
              .withInput("Input", juce::AudioChannelSet::stereo(), true)
              .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      // Build the parameter tree: (this processor, no undo manager, tree name, params).
      apvts(*this, nullptr, "Parameters", createParameterLayout()) {}

// Declares every parameter the plugin exposes. Called once, from the constructor.
juce::AudioProcessorValueTreeState::ParameterLayout PannerAudioProcessor::createParameterLayout() {
  juce::AudioProcessorValueTreeState::ParameterLayout layout;

  // --- Add parameters here. Example (uncomment & adapt): ---
  //   ParameterID{"ID", 1} : the string ID you read in processBlock + a version hint.
  //   "Param Name"         : shown in the host.
  //   NormalisableRange    : min, max, step.
  //   0.5f                 : default value.
  layout.add(std::make_unique<juce::AudioParameterFloat>(
      juce::ParameterID{"PAN", 1}, "Panning",
      juce::NormalisableRange<float>(-1.0f, 1.0f, 0.01f), 0.0f));

  return layout;
}

// Called before playback. Prepare anything that depends on sample rate / block size.
void PannerAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
  // e.g. build a juce::dsp::ProcessSpec and call yourDsp.prepare(spec) here,
  //      allocate delay buffers, compute filter coefficients, etc.
  smoothedPan = apvts.getRawParameterValue("PAN")->load(); // snap, no ramp
  const double smoothingSeconds = 0.05f;
  smoothCoeff = static_cast<float>(1.0f - std::exp(-1.0f / (sampleRate * smoothingSeconds)));
  juce::ignoreUnused(samplesPerBlock); // Silence "unused" warnings for now.
}

// Vet the layouts the host proposes. Panning left against right only means anything
// with two channels on each side, so accept stereo-in/stereo-out and nothing else.
// Rejecting a layout is not a limitation — it is how the host learns to give us a
// buffer we can actually handle, instead of a mono one we would read past the end of.
bool PannerAudioProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const {
  const auto stereo = juce::AudioChannelSet::stereo();
  return layouts.getMainInputChannelSet() == stereo && layouts.getMainOutputChannelSet() == stereo;
}

// The audio callback. `buffer` already holds the INPUT samples; edit it in place.
void PannerAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) {
  juce::ScopedNoDenormals noDenormals; // Disable CPU denormals for this scope (always do this).

  const float pan = apvts.getRawParameterValue("PAN")->load();

  auto* dataL = buffer.getWritePointer(0);
  auto* dataR = buffer.getWritePointer(1);

  for (int i = 0; i < buffer.getNumSamples(); ++i) {
    smoothedPan += (pan - smoothedPan) * smoothCoeff;

    const float leftGain = (1.0f - smoothedPan) / 2.0f;
    const float rightGain = (1.0f + smoothedPan) / 2.0f;

    dataL[i] *= leftGain;
    dataR[i] *= rightGain;
  }
}

// The host calls this to create the plugin's window. `*this` lets the editor talk back.
juce::AudioProcessorEditor* PannerAudioProcessor::createEditor() { return new PannerAudioProcessorEditor(*this); }

// Save: serialize the whole parameter tree to the host's memory block (XML -> binary).
void PannerAudioProcessor::getStateInformation(juce::MemoryBlock& destData) {
  if (auto xml = apvts.copyState().createXml())
    copyXmlToBinary(*xml, destData);
}

// Restore: the reverse. Only replace state if the saved data matches our tree type.
void PannerAudioProcessor::setStateInformation(const void* data, int sizeInBytes) {
  if (auto xml = getXmlFromBinary(data, sizeInBytes))
    if (xml->hasTagName(apvts.state.getType()))
      apvts.replaceState(juce::ValueTree::fromXml(*xml));
}

// JUCE's entry point: a free function (not a class member) the host calls to create
// the plugin. This is WHY the constructor must be public.
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() { return new PannerAudioProcessor(); }
