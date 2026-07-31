// ─────────────────────────────────────────────────────────────────────────────
// PluginEditor.h — the plugin's GUI. An AudioProcessorEditor IS-A juce::Component
// (JUCE's base class for anything that draws on screen and handles mouse/keys).
// ─────────────────────────────────────────────────────────────────────────────
#pragma once
#include "PluginProcessor.h" // We name the PannerAudioProcessor type below, so we include it.
#include <JuceHeader.h>

class PannerAudioProcessorEditor final : public juce::AudioProcessorEditor {
public:
  // explicit = don't let C++ silently convert a processor into an editor.
  explicit PannerAudioProcessorEditor(PannerAudioProcessor&);
  ~PannerAudioProcessorEditor() override = default;

  void paint(juce::Graphics&) override; // Draw the background/contents.
  void resized() override;              // Lay out child components when size changes.

private:
  juce::Slider panningSlider;
  std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> panningAttachment;

  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PannerAudioProcessorEditor)
};
