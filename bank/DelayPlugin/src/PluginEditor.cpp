// ─────────────────────────────────────────────────────────────────────────────
// PluginEditor.cpp — defines the GUI declared in PluginEditor.h.
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginEditor.h"

// Constructor. Pass &p to the base editor (it wants a POINTER and stores the
// reference for us as `processor`). No need to keep our own copy.
DelayAudioProcessorEditor::DelayAudioProcessorEditor(DelayAudioProcessor& p) : juce::AudioProcessorEditor(&p) {
  // For each control: configure it, then addAndMakeVisible(it), then create its
  // parameter attachment. To reach the typed processor here, cast the base member:
  //   auto& proc = static_cast<DelayAudioProcessor&>(processor);
  //   SliderAttachment(proc.apvts, "PARAM_ID", mySlider);
  setSize(400, 300); // Initial window size. Without this the editor has zero size.
}

// Called whenever the UI must redraw. `g` is the drawing context.
void DelayAudioProcessorEditor::paint(juce::Graphics& g) {
  g.fillAll(juce::Colours::darkgrey); // Background.
  g.setColour(juce::Colours::white);  // Text colour.
  g.setFont(20.0f);                   // Text size.
  // Draw the plugin's name centered in the whole window (getLocalBounds()).
  g.drawText(JucePlugin_Name, getLocalBounds(), juce::Justification::centred, true);
}

// Called on startup and every resize. Position child components here (NOT in paint()).
void DelayAudioProcessorEditor::resized() {
  // e.g. mySlider.setBounds(getLocalBounds().reduced(40));
}
