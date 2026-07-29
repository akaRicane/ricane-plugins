#pragma once
#include "PluginProcessor.h"
#include <JuceHeader.h>

class GainAudioProcessorEditor final : public juce::AudioProcessorEditor {
public:
  explicit GainAudioProcessorEditor(GainAudioProcessor&);
  ~GainAudioProcessorEditor() override = default;

  void paint(juce::Graphics&) override;
  void resized() override;

private:
  GainAudioProcessor& processor;
  juce::Slider gainSlider;
  std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> gainAttachment;
  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GainAudioProcessorEditor)
};