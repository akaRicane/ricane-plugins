#include "PluginEditor.h"

GainAudioProcessorEditor::GainAudioProcessorEditor(GainAudioProcessor& p)
  : juce::AudioProcessorEditor(&p), processor(p)
{
  gainSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
  gainSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
  addAndMakeVisible(gainSlider);

  gainAttachment =
      std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(processor.apvts, "GAIN_DB", gainSlider);

  setSize(400, 300);
}

void GainAudioProcessorEditor::paint(juce::Graphics& g) {
  g.fillAll(juce::Colours::darkgrey);
  g.setColour(juce::Colours::yellow);
  g.setFont(20.0f);
  g.drawText("Gain Plugin - passthrough", getLocalBounds(), juce::Justification::centred, true);
}

void GainAudioProcessorEditor::resized() { gainSlider.setBounds(getLocalBounds().reduced(40)); }
