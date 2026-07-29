# Editor Setup (IntelliSense & formatting)

How to get a clean editor: no red squiggles on `juce::` symbols, JUCE ignored by the linter,
and your own code auto-formatted to `.clang-format`. Targets **VS Code + Microsoft C/C++
extension (`cpptools`)** on macOS.

## The problem

`#include <JuceHeader.h>` and every `juce::` symbol show up **red**, and the Problems panel
is full — even though the plugin **builds fine**. That red is *not* a compiler error: it's the
editor's IntelliSense not knowing JUCE's include paths and defines. The build knows them; the
editor doesn't — until we hand them over.

## The fix, in two parts

### 1. Make CMake emit `compile_commands.json`

`compile_commands.json` is a list of the exact compiler command (include paths, defines, flags)
for every source file. IntelliSense can read it and instantly resolve all of JUCE.

Add this near the top of the plugin's `CMakeLists.txt` (before the targets):

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

Then reconfigure once so it's generated:

```bash
cd bank/<plugin>
cmake -B build -S .
# creates build/compile_commands.json
```

### 2. Point the editor at it — `.vscode/settings.json`

At the workspace root, `.vscode/settings.json`:

```jsonc
{
  // IntelliSense uses the real compiler flags -> resolves all juce:: symbols.
  // One entry per plugin build; add a line when you create a new plugin.
  "C_Cpp.default.compileCommands": [
    "${workspaceFolder}/bank/GainPlugin/build/compile_commands.json"
  ],

  // Don't analyze the JUCE framework or build output (that was the red).
  "C_Cpp.files.exclude": {
    "**/JUCE/**": true,
    "**/build/**": true
  },

  // Keep search + file-watching off the huge framework & build trees.
  "search.exclude":        { "**/JUCE/**": true, "**/build/**": true },
  "files.watcherExclude":  { "**/JUCE/**": true, "**/build/**": true },

  // Format YOUR code to .clang-format on save (bundled clang-format).
  "editor.formatOnSave": true,
  "C_Cpp.formatting": "clangFormat",
  "C_Cpp.clang_format_style": "file",

  // Redundant third-party linter (needs external tools); off = less noise.
  "c-cpp-flylint.enable": false
}
```

## Apply it

1. **Reload the window**: Command Palette (`⌘⇧P`) → **Developer: Reload Window**. IntelliSense
   re-parses using `compile_commands.json`; the red clears in a few seconds.
2. **Reformat existing files**: format-on-save only fires on save. To fix files already typed in
   another style, open each and **save** (or **Format Document**, `⇧⌥F`) — they snap to
   `.clang-format` (here: Allman braces, 2-space indent).

## What each setting does

| Setting | Effect |
|---|---|
| `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)` | CMake writes `build/compile_commands.json`. |
| `C_Cpp.default.compileCommands` | cpptools resolves every JUCE include → your code stops being red. |
| `C_Cpp.files.exclude` (JUCE, build) | cpptools ignores the framework & build output entirely. |
| `search.exclude` / `files.watcherExclude` | Search and the file-watcher skip JUCE/build (noise + perf). |
| `editor.formatOnSave` + `clang_format_style: file` | Auto-format your code to `.clang-format` on save. |
| `c-cpp-flylint.enable: false` | Disables a second, redundant linter (a common red source). |

## Notes

- **New plugin?** Add one line to the `compileCommands` array pointing at that plugin's
  `build/compile_commands.json`. The `set(...)` line is already in the CMakeLists template, so
  each plugin generates its own.
- **`compile_commands.json` lives in `build/`** — it's generated and git-ignored. Regenerate it
  any time with `cmake -B build -S .`.
- **`.vscode/` is git-ignored** by default, so this config stays local. Un-ignore
  `.vscode/settings.json` if you want it tracked in the repo.
- **clang-format binary**: not required on `PATH` — cpptools bundles its own and honors the
  repo's `.clang-format` via `clang_format_style: file`.
