# ─────────────────────────────────────────────────────────────────────────────
# EXAMPLE / TEMPLATE plugin — heavily annotated for learning.
# Copy this whole folder into bank/<Name>/ and rename to start a real plugin.
# See documentation/setup/starter_template.md for the step-by-step.
# ─────────────────────────────────────────────────────────────────────────────

# The oldest CMake version allowed. JUCE 8 needs a modern CMake (>= 3.22).
cmake_minimum_required(VERSION 3.22)

# Names this build and gives it a version (JUCE uses it for plugin metadata).
project(NewPlugin VERSION 0.1.0)

# Write build/compile_commands.json — the file that tells the editor's IntelliSense
# the real include paths & defines, so juce:: symbols resolve (no red squiggles).
# See documentation/setup/editor_setup.md.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Bring the JUCE framework into this build. The path is relative to THIS file:
#   ../../JUCE  ->  up two folders to the repo root, then into JUCE/
# (True both here, at documentation/example_plugin/, and at bank/<Name>/.)
# The 2nd word (JUCE) just names the folder CMake uses for JUCE's output.
add_subdirectory(../../JUCE JUCE)

# Optional plugin validation. Off unless you configure with -DENABLE_PLUGINVAL=ON,
# so it costs nothing until you ask for it. Validating a plugin catches the bugs
# that only appear in a real host — see documentation/tools/pluginval.md.
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Pluginval.cmake)

# Formats to build. pluginval_formats() appends AU when validation is enabled,
# because pluginval insists on an AU target to validate on macOS.
set(PLUGIN_FORMATS VST3 Standalone)
pluginval_formats(PLUGIN_FORMATS)

# THE key call: describe the plugin. JUCE turns this into several build targets
# (a VST3, a Standalone app, and a shared-code library the two link against).
juce_add_plugin(NewPlugin
    PRODUCT_NAME "New Plugin"           # Name shown to the user / in the DAW
    COMPANY_NAME "Ricane"               # Manufacturer name shown in the host
    PLUGIN_MANUFACTURER_CODE Rcan       # 4-char manufacturer ID (registry code)
    PLUGIN_CODE Newp                    # 4-char plugin ID — CHANGE THIS, it must be
                                        # unique per plugin (two plugins sharing a
                                        # code confuses hosts)
    FORMATS ${PLUGIN_FORMATS}           # Which formats to build
    IS_SYNTH FALSE                      # Effect (processes audio), not an instrument
    NEEDS_MIDI_INPUT FALSE              # No MIDI in
    NEEDS_MIDI_OUTPUT FALSE             # No MIDI out
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE   # UI doesn't capture typing (no text fields)
    MICROPHONE_PERMISSION_ENABLED TRUE  # Adds the macOS mic-permission key so the
    MICROPHONE_PERMISSION_TEXT "New Plugin needs microphone access to process input audio."  # Standalone can receive input
    COPY_PLUGIN_AFTER_BUILD TRUE        # Auto-install the VST3 to ~/Library/Audio/Plug-Ins/VST3/
)

# Generates <JuceHeader.h> — the umbrella header the .cpp/.h files #include.
juce_generate_juce_header(NewPlugin)

# The source files that make up THIS plugin (PRIVATE = only this target uses them).
target_sources(NewPlugin PRIVATE
    src/PluginProcessor.cpp
    src/PluginEditor.cpp
)

# Compile as C++17.
target_compile_features(NewPlugin PRIVATE cxx_std_17)

# Say "this plugin has no VST2 past", avoiding a hard #error about VST2/VST3
# parameter-automation conflicts. (PUBLIC = applies to this target's compile.)
target_compile_definitions(NewPlugin PUBLIC JUCE_VST3_CAN_REPLACE_VST2=0)

# The JUCE modules to link. Add a module line here to unlock its classes:
#   juce_audio_utils         -> AudioProcessor + plugin plumbing
#   juce_dsp                 -> juce::dsp::Gain and other DSP building blocks
#   juce_recommended_*_flags -> JUCE's suggested compiler & warning settings
target_link_libraries(NewPlugin PRIVATE
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags
)

# Adds pluginval and a 'validate' target, but only when -DENABLE_PLUGINVAL=ON.
# Must come after juce_add_plugin: it reads the plugin's target properties.
pluginval_enable(NewPlugin)
