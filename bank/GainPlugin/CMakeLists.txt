# ─────────────────────────────────────────────────────────────────────────────
# GainPlugin — CMake build description
# A self-contained JUCE plugin: this file pulls JUCE in and describes the plugin.
# ─────────────────────────────────────────────────────────────────────────────

# Minimum CMake version. JUCE 8 needs a reasonably modern CMake.
cmake_minimum_required(VERSION 3.22)

# Names this project and sets a version number (used by JUCE for metadata).
project(GainPlugin VERSION 0.1.0)

# Emit build/compile_commands.json so the editor's IntelliSense knows the
# real include paths / defines (resolves all the juce:: symbols). See
# documentation/editor_setup.md.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Pull the JUCE framework into this build. The path is relative to THIS file:
#   ../../JUCE  -> up to bank/, up to the repo root, into JUCE/
# The second argument (JUCE) is just the sub-folder name CMake uses for JUCE's
# build output inside our build/ tree (required because JUCE lives outside it).
add_subdirectory(../../JUCE JUCE)

# Optional plugin validation (off unless -DENABLE_PLUGINVAL=ON).
# See documentation/testing_with_pluginval.md.
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Pluginval.cmake)

# Formats to build. pluginval_formats() appends AU when validation is enabled,
# because pluginval insists on an AU target to validate on macOS.
set(PLUGIN_FORMATS VST3 Standalone)
pluginval_formats(PLUGIN_FORMATS)

# The heart of the file: describe the plugin. JUCE turns this one call into
# several build targets (VST3, Standalone, and a shared-code library).
juce_add_plugin(GainPlugin
    PRODUCT_NAME "Gain Plugin"                 # Display name of the plugin
    COMPANY_NAME "Ricane"                      # Manufacturer name shown in the host
    PLUGIN_MANUFACTURER_CODE Rcan              # 4-char manufacturer ID (registry code)
    PLUGIN_CODE Gain                           # 4-char plugin ID
    FORMATS ${PLUGIN_FORMATS}                  # Which formats to build
    IS_SYNTH FALSE                             # Audio effect, not an instrument
    NEEDS_MIDI_INPUT FALSE                      # No MIDI in
    NEEDS_MIDI_OUTPUT FALSE                     # No MIDI out
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE          # Editor doesn't capture keystrokes
    MICROPHONE_PERMISSION_ENABLED TRUE         # Adds NSMicrophoneUsageDescription so the
    MICROPHONE_PERMISSION_TEXT "Gain Plugin needs microphone access to process input audio."  # Standalone can use the mic on macOS
    COPY_PLUGIN_AFTER_BUILD TRUE               # Auto-install the VST3 to ~/Library/Audio/Plug-Ins/VST3/
)

# Generates the <JuceHeader.h> umbrella header that the source files #include.
juce_generate_juce_header(GainPlugin)

# The source files that make up the plugin (PRIVATE = only this target uses them).
target_sources(GainPlugin PRIVATE
    src/PluginProcessor.cpp
    src/PluginEditor.cpp
)

# Compile as C++17.
target_compile_features(GainPlugin PRIVATE cxx_std_17)

# Tell JUCE this plugin has no VST2 past, avoiding a hard #error about VST2/VST3
# parameter-automation conflicts. (PUBLIC = applies to this target's compilation.)
target_compile_definitions(GainPlugin PUBLIC JUCE_VST3_CAN_REPLACE_VST2=0)

# The JUCE modules this plugin links against. Add a module here to use its classes:
#   juce_audio_utils            - AudioProcessor, plugin hosting/utility classes
#   juce_dsp                    - juce::dsp::Gain and the DSP building blocks
#   juce_recommended_*_flags    - JUCE's suggested compiler & warning settings
target_link_libraries(GainPlugin PRIVATE
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags
)

# Adds pluginval and a 'validate' target, but only when -DENABLE_PLUGINVAL=ON.
# Must come after juce_add_plugin: it reads the plugin's target properties.
pluginval_enable(GainPlugin)
