cmake_minimum_required(VERSION 3.22)
project(GainPlugin VERSION 0.1.0)

add_subdirectory(../../JUCE JUCE)

juce_add_plugin(GainPlugin
    PRODUCT_NAME "Gain Plugin"
    COMPANY_NAME "Ricane"
    PLUGIN_MANUFACTURER_CODE Rcan
    PLUGIN_CODE Gain
    FORMATS VST3 Standalone
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    MICROPHONE_PERMISSION_ENABLED TRUE
    MICROPHONE_PERMISSION_TEXT "Gain Plugin needs microphone access to process input audio."
    COPY_PLUGIN_AFTER_BUILD TRUE
)

juce_generate_juce_header(GainPlugin)

target_sources(GainPlugin PRIVATE
    src/PluginProcessor.cpp
    src/PluginEditor.cpp
)

target_compile_features(GainPlugin PRIVATE cxx_std_17)
target_compile_definitions(GainPlugin PUBLIC JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(GainPlugin PRIVATE
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags
)
