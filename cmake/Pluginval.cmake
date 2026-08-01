# ─────────────────────────────────────────────────────────────────────────────
# Pluginval.cmake — optional plugin validation, shared by every plugin here.
#
# pluginval (tools/pluginval/, a git submodule) loads a built plugin and abuses
# it the way a strict host would. See documentation/tools/pluginval.md.
#
# A plugin's CMakeLists.txt uses this in three steps:
#
#     include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Pluginval.cmake)
#
#     set(PLUGIN_FORMATS VST3 Standalone)
#     pluginval_formats(PLUGIN_FORMATS)          # BEFORE juce_add_plugin
#     juce_add_plugin(MyPlugin ... FORMATS ${PLUGIN_FORMATS} ...)
#
#     pluginval_enable(MyPlugin)                 # AFTER juce_add_plugin
#
# Everything is inert unless you configure with -DENABLE_PLUGINVAL=ON, because
# turning it on builds pluginval — a whole JUCE application — inside this
# plugin's build tree (~280 MB, several minutes).
#
# These are macros, not functions, so they run in the caller's variable scope.
# That matters: pluginval_enable() calls add_subdirectory(), which has to see
# the settings below.
# ─────────────────────────────────────────────────────────────────────────────

include_guard(GLOBAL)

option(ENABLE_PLUGINVAL "Build pluginval in-tree and add a 'validate' target" OFF)

# Strictness of the 'validate' target, 1-10. 5 is pluginval's recommended
# minimum for host compatibility; 10 adds parameter fuzzing and thread-safety
# tests. Override at configure time with -DPLUGINVAL_STRICTNESS=10.
set(PLUGINVAL_STRICTNESS 5 CACHE STRING "pluginval strictness level (1-10)")
set_property(CACHE PLUGINVAL_STRICTNESS PROPERTY STRINGS 1 2 3 4 5 6 7 8 9 10)

# The repo root, derived from this file's location (repo/cmake/Pluginval.cmake).
get_filename_component(PLUGINVAL_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

# ─────────────────────────────────────────────────────────────────────────────
# pluginval_formats(<listVar>) — call BEFORE juce_add_plugin.
#
# Appends AU on macOS when validation is enabled. This is not optional and not
# our preference: pluginval's CMake integration hardcodes "<Project>_AU" as the
# target it validates on macOS, then calls get_target_property() on it without
# checking it exists. No AU target means configuring dies with a bare
# "non-existent target" error. Building AU also gets us Apple's own auval run
# as part of validation, which is a genuine bonus.
# ─────────────────────────────────────────────────────────────────────────────
macro(pluginval_formats formats_var)
    if(ENABLE_PLUGINVAL AND APPLE)
        list(APPEND ${formats_var} AU)
    endif()
endmacro()

# ─────────────────────────────────────────────────────────────────────────────
# pluginval_enable(<pluginTarget>) — call AFTER juce_add_plugin.
#
# Adds the pluginval build and a 'validate' target that validates the VST3.
# ─────────────────────────────────────────────────────────────────────────────
macro(pluginval_enable plugin_target)
    if(ENABLE_PLUGINVAL)
        # pluginval pulls its dependencies with CPM at configure time. Point CPM
        # at one cache shared by every plugin, so the second plugin you validate
        # reuses the first one's downloads instead of re-fetching them.
        set(CPM_SOURCE_CACHE "${PLUGINVAL_REPO_ROOT}/.cpm-cache" CACHE PATH "")

        # rtcheck intercepts allocations and lock-taking on the audio thread —
        # the most valuable thing here. pluginval only enables it automatically
        # when it is the top-level project, so as a dependency we must ask.
        set(PLUGINVAL_ENABLE_RTCHECK ON)

        # Skip the embedded Steinberg VST3 validator: it makes CPM fetch and
        # build the entire VST3 SDK. Set to ON for spec-conformance checks too.
        set(PLUGINVAL_VST3_VALIDATOR OFF CACHE BOOL "" FORCE)

        add_subdirectory("${PLUGINVAL_REPO_ROOT}/tools/pluginval" pluginval)

        # pluginval's own target (<Project>_pluginval_cli) validates the AU at a
        # hardcoded strictness of 10. This one validates the VST3 — the format
        # that actually gets installed — at PLUGINVAL_STRICTNESS.
        get_target_property(_pv_artefact ${plugin_target}_VST3 JUCE_PLUGIN_ARTEFACT_FILE)

        add_custom_target(validate
            COMMAND $<TARGET_FILE:pluginval>
                    --strictness-level ${PLUGINVAL_STRICTNESS}
                    --rtcheck relaxed
                    --validate "${_pv_artefact}"
            DEPENDS pluginval ${plugin_target}_VST3
            COMMENT "Validating the ${plugin_target} VST3 with pluginval"
            USES_TERMINAL)
    endif()
endmacro()
