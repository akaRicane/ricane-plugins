// ─────────────────────────────────────────────────────────────────────────────
// PluginEditor.h — the plugin's GUI. An AudioProcessorEditor IS-A juce::Component
// (JUCE's base class for anything that draws on screen and handles mouse/keys).
// ─────────────────────────────────────────────────────────────────────────────
#pragma once
#include "PluginProcessor.h" // We name the DelayAudioProcessor type below, so we include it.
#include <JuceHeader.h>

class DelayAudioProcessorEditor final : public juce::AudioProcessorEditor {
public:
  // explicit = don't let C++ silently convert a processor into an editor.
  explicit DelayAudioProcessorEditor(DelayAudioProcessor&);
  ~DelayAudioProcessorEditor() override = default;

  void paint(juce::Graphics&) override; // Draw the background/contents.
  void resized() override;              // Lay out child components when size changes.

private:
  // Each knob pairs with an Attachment. The attachment is what keeps the slider and
  // the parameter in sync BOTH ways — drag the knob and the parameter follows; move
  // it from host automation and the knob follows. Declare the slider FIRST: members
  // are destroyed in reverse order, so the attachment must die before the slider it
  // points at.
  juce::Slider delayTimeSlider;
  juce::Label delayTimeLabel;
  std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> delayTimeAttachement;

  juce::Slider wetDrySlider;
  juce::Label wetDryLabel;
  std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> wetDryAttachement;

  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(DelayAudioProcessorEditor)
};
