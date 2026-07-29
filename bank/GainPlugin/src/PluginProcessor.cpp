#include "PluginProcessor.h"
#include "PluginEditor.h"

GainAudioProcessor::GainAudioProcessor()
    : juce::AudioProcessor(
          juce::AudioProcessor::BusesProperties()
              .withInput("Input", juce::AudioChannelSet::stereo(), true)
              .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      apvts(*this, nullptr, "Parameters", createParameterLayout()) {}

juce::AudioProcessorValueTreeState::ParameterLayout GainAudioProcessor::createParameterLayout() {
  juce::AudioProcessorValueTreeState::ParameterLayout layout;

  layout.add(
      std::make_unique<juce::AudioParameterFloat>(
          juce::ParameterID{"GAIN_DB", 1}, "Gain", juce::NormalisableRange<float>(-60.0f, 12.0f, 0.1f), 0.0f));

  return layout;
}

void GainAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock) {
  // juce::ignoreUnused(sampleRate, samplesPerBlock);
  juce::dsp::ProcessSpec spec;
  spec.sampleRate = sampleRate;
  spec.maximumBlockSize = (juce::uint32)samplesPerBlock;
  spec.numChannels = (juce::uint32)getTotalNumOutputChannels();

  gain.prepare(spec);
  gain.setRampDurationSeconds(0.05);
}

void GainAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) {
  juce::ScopedNoDenormals noDenormals;

  const float gainDb = apvts.getRawParameterValue("GAIN_DB")->load();
  gain.setGainDecibels(gainDb);

  juce::dsp::AudioBlock<float> block(buffer);
  juce::dsp::ProcessContextReplacing<float> context(block);
  gain.process(context);
}

juce::AudioProcessorEditor* GainAudioProcessor::createEditor() { return new GainAudioProcessorEditor(*this); }

void GainAudioProcessor::getStateInformation(juce::MemoryBlock& destData) {
  // juce::ignoreUnused(destData);
  if (auto xml = apvts.copyState().createXml())
    copyXmlToBinary(*xml, destData);
}

void GainAudioProcessor::setStateInformation(const void* data, int sizeInBytes) {
  // juce::ignoreUnused(data, sizeInBytes);
  if (auto xml = getXmlFromBinary(data, sizeInBytes))
    if (xml->hasTagName(apvts.state.getType()))
      apvts.replaceState(juce::ValueTree::fromXml(*xml));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter() { return new GainAudioProcessor(); }