// ─────────────────────────────────────────────────────────────────────────────
// PluginEditor.cpp — defines the GUI declared in PluginEditor.h.
// ─────────────────────────────────────────────────────────────────────────────
#include "PluginEditor.h"

// Constructor. Pass &p to the base editor (it wants a POINTER and stores the
// reference for us as `processor`). No need to keep our own copy.
DelayAudioProcessorEditor::DelayAudioProcessorEditor(DelayAudioProcessor& p) : juce::AudioProcessorEditor(&p) {

  delayTimeSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
  delayTimeSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
  delayTimeSlider.setTextValueSuffix(" s");
  addAndMakeVisible(delayTimeSlider);

  delayTimeLabel.setText("Delay time", juce::dontSendNotification);
  delayTimeLabel.setJustificationType(juce::Justification::centred);
  addAndMakeVisible(delayTimeLabel);

  // The ID string must match createParameterLayout() EXACTLY. There's no compiler
  // check on it: a typo builds fine and fails at runtime, because the attachment
  // looks the parameter up by name and asserts when it finds nothing.
  delayTimeAttachement =
      std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(p.apvts, "DELAY_TIME", delayTimeSlider);

  wetDrySlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
  wetDrySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
  addAndMakeVisible(wetDrySlider);

  wetDryLabel.setText("Dry / Wet", juce::dontSendNotification);
  wetDryLabel.setJustificationType(juce::Justification::centred);
  addAndMakeVisible(wetDryLabel);

  wetDryAttachement =
      std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(p.apvts, "DRY_WET", wetDrySlider);

  setSize(400, 300); // Initial window size. Without this the editor has zero size.
}

// Called whenever the UI must redraw. `g` is the drawing context.
void DelayAudioProcessorEditor::paint(juce::Graphics& g) {
  g.fillAll(juce::Colours::darkgrey); // Background.
  g.setColour(juce::Colours::white);  // Text colour.
  g.setFont(20.0f);                   // Text size.
  // Title in a strip along the top, so it doesn't sit underneath the knobs.
  g.drawText(JucePlugin_Name, getLocalBounds().removeFromTop(40), juce::Justification::centred, true);
}

// Called on startup and every resize. Position child components here (NOT in paint()).
// A component whose bounds are never set is 0x0 — present, but invisible.
void DelayAudioProcessorEditor::resized() {
  auto area = getLocalBounds().reduced(20);
  area.removeFromTop(40); // Leave the title strip alone.

  // removeFromLeft() SLICES the rectangle: it returns the left half and shrinks
  // `area` to what's left, so the second call gets the other half automatically.
  auto leftHalf = area.removeFromLeft(area.getWidth() / 2);
  auto rightHalf = area;

  // Labels sit above their knobs; removeFromTop slices the same way.
  delayTimeLabel.setBounds(leftHalf.removeFromTop(24));
  delayTimeSlider.setBounds(leftHalf.reduced(10));

  wetDryLabel.setBounds(rightHalf.removeFromTop(24));
  wetDrySlider.setBounds(rightHalf.reduced(10));
}
