// ─────────────────────────────────────────────────────────────────────────────
// PluginProcessor.cpp — defines the functions declared in PluginProcessor.h.
// `NewPluginProcessor::foo` means "foo belonging to NewPluginProcessor".
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginProcessor.h"
#include "PluginEditor.h" // Needed because createEditor() below builds an editor.

// Constructor. The part after ':' is the MEMBER-INITIALIZER LIST — it runs before
// the {} body and initializes the base class and members.
NewPluginProcessor::NewPluginProcessor()
    // Tell the base AudioProcessor our bus layout: one stereo in, one stereo out.
    : juce::AudioProcessor(
          juce::AudioProcessor::BusesProperties()
              .withInput("Input", juce::AudioChannelSet::stereo(), true)
              .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      // Build the parameter tree: (this processor, no undo manager, tree name, params).
      apvts(*this, nullptr, "Parameters", createParameterLayout()) {}

// Declares every parameter the plugin exposes. Called once, from the constructor.
juce::AudioProcessorValueTreeState::ParameterLayout NewPluginProcessor::createParameterLayout() {
  juce::AudioProcessorValueTreeState::ParameterLayout layout;

  // --- Add parameters here. Example (uncomment & adapt): ---
  //   ParameterID{"ID", 1} : the string ID you read in processBlock + a version hint.
  //   "Param Name"         : shown in the host.
  //   NormalisableRange    : min, max, step.
  //   0.5f                 : default value.
  // layout.add(std::make_unique<juce::AudioParameterFloat>(
  //     juce::ParameterID{"PARAM_ID", 1}, "Param Name",
  //     juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f), 0.5f));

  return layout;
}

// Called before playback. Prepare anything that depends on sample rate / block size.
void NewPluginProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
  // e.g. build a juce::dsp::ProcessSpec and call yourDsp.prepare(spec) here,
  //      allocate delay buffers, compute filter coefficients, etc.
  juce::ignoreUnused(sampleRate, samplesPerBlock); // Silence "unused" warnings for now.
}

// The audio callback. `buffer` already holds the INPUT samples; edit it in place.
void NewPluginProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) {
  juce::ScopedNoDenormals noDenormals; // Disable CPU denormals for this scope (always do this).

  // --- Your DSP goes here. Example (read a parameter atomically): ---
  // const float value = apvts.getRawParameterValue("PARAM_ID")->load();
  // ... then loop over channels/samples, or hand the buffer to a juce::dsp object.

  // Passthrough: we deliberately leave the buffer untouched (input == output).
  juce::ignoreUnused(buffer);
}

// The host calls this to create the plugin's window. `*this` lets the editor talk back.
juce::AudioProcessorEditor* NewPluginProcessor::createEditor() { return new NewPluginEditor(*this); }

// Save: serialize the whole parameter tree to the host's memory block (XML -> binary).
void NewPluginProcessor::getStateInformation(juce::MemoryBlock& destData) {
  if (auto xml = apvts.copyState().createXml())
    copyXmlToBinary(*xml, destData);
}

// Restore: the reverse. Only replace state if the saved data matches our tree type.
void NewPluginProcessor::setStateInformation(const void* data, int sizeInBytes) {
  if (auto xml = getXmlFromBinary(data, sizeInBytes))
    if (xml->hasTagName(apvts.state.getType()))
      apvts.replaceState(juce::ValueTree::fromXml(*xml));
}

// JUCE's entry point: a free function (not a class member) the host calls to create
// the plugin. This is WHY the constructor must be public.
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() { return new NewPluginProcessor(); }
