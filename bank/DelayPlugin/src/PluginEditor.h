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
  // NOTE: the base AudioProcessorEditor ALREADY stores the processor as `processor`
  // (typed AudioProcessor&) — don't declare your own, it would shadow the base one.
  // When you need YOUR processor type (e.g. to reach apvts), cast the base member:
  //   auto& proc = static_cast<DelayAudioProcessor&>(processor);

  // Add controls here. IMPORTANT: declare a control's Attachment AFTER the control,
  // because members are destroyed in REVERSE order and the attachment points at it.
  //   juce::Slider mySlider;
  //   std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> myAttachment;

  JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(DelayAudioProcessorEditor)
};
