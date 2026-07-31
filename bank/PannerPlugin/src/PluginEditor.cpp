// ─────────────────────────────────────────────────────────────────────────────
// PluginEditor.cpp — defines the GUI declared in PluginEditor.h.
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginEditor.h"

// Constructor. Pass &p to the base editor (it wants a POINTER and stores the
// reference for us as `processor`). No need to keep our own copy.
PannerAudioProcessorEditor::PannerAudioProcessorEditor(PannerAudioProcessor& p)
    : juce::AudioProcessorEditor(&p) {
  // For each control: configure it, then addAndMakeVisible(it), then create its
  // parameter attachment. To reach the typed processor here, cast the base member:
  //   auto& proc = static_cast<PannerAudioProcessorProcessor&>(processor);
  //   SliderAttachment(proc.apvts, "PARAM_ID", mySlider);

  panningSlider.setSliderStyle(juce::Slider::LinearHorizontal);
  panningSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
  addAndMakeVisible(panningSlider);

  panningAttachment =
    std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(p.apvts, "PAN", panningSlider);

  setSize(400, 300); // Initial window size. Without this the editor has zero size.
}

// Called whenever the UI must redraw. `g` is the drawing context.
void PannerAudioProcessorEditor::paint(juce::Graphics& g) {
  g.fillAll(juce::Colours::darkgrey); // Background.
  g.setColour(juce::Colours::white);  // Text colour.
  g.setFont(20.0f);                   // Text size.
  // Draw the plugin's name centered in the whole window (getLocalBounds()).
  g.drawText(JucePlugin_Name, getLocalBounds(), juce::Justification::centred, true);
}

// Called on startup and every resize. Position child components here (NOT in paint()).
void PannerAudioProcessorEditor::resized() {
  panningSlider.setBounds(getLocalBounds().reduced(40));
}
