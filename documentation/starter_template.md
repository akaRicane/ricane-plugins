# Starting a new plugin from the example

The repo ships a fully-annotated, ready-to-copy skeleton at
[`documentation/example_plugin/`](example_plugin). Every line is commented for learning, and it
**builds, loads, and passes audio through untouched**, with the parameter system (`apvts`)
already wired and markers showing where DSP and controls go.

```
documentation/example_plugin/
├── CMakeLists.txt
└── src/
    ├── PluginProcessor.h
    ├── PluginProcessor.cpp
    ├── PluginEditor.h
    └── PluginEditor.cpp
```

This guide turns that example into a real plugin in `bank/`.

> The example is annotated to *teach*. In a real plugin you'll want to trim the comments
> down to what's useful to you — the code itself is production-ready.

## Steps

### 1. Copy the example into bank/
```bash
cp -r documentation/example_plugin bank/Panner   # replace "Panner" with your plugin name
```

### 2. Replace the placeholders
The example uses these placeholders — replace them across all four source files and the
CMakeLists:

| Placeholder | Replace with | Where |
|---|---|---|
| `NewPlugin` | your name, e.g. `Panner` (no spaces) | CMake target, class names, entry point |
| `New Plugin` | display name, e.g. `Panner` | `PRODUCT_NAME`, mic-permission text |
| `Newp` | a unique 4-char `PLUGIN_CODE` | CMakeLists |

By hand, or with `sed` from inside the new folder:
```bash
cd bank/Panner
grep -rl 'NewPlugin' . | xargs sed -i '' 's/NewPlugin/Panner/g'      # class + target
grep -rl 'New Plugin' . | xargs sed -i '' 's/New Plugin/Panner/g'    # display name
sed -i '' 's/PLUGIN_CODE Newp/PLUGIN_CODE Pann/' CMakeLists.txt      # 4-char code
```
(The `sed -i ''` empty-quotes form is required on macOS.)

### 3. Register it for IntelliSense
Add one line to the `compileCommands` array in [`.vscode/settings.json`](../.vscode/settings.json):
```jsonc
"${workspaceFolder}/bank/Panner/build/compile_commands.json"
```

### 4. Build it
```bash
./utils/build.sh -o Panner    # first run configures, then builds and opens the Standalone
```
You should get a window titled with your plugin name, passing audio through. Now start adding
DSP.

### 5. Validate it
```bash
./utils/validate.sh Panner    # check it behaves in a real host
```
Do this once the DSP works, and again before you call the plugin finished. It catches the bugs
a Standalone build never will — see [`testing_with_pluginval.md`](testing_with_pluginval.md).

Two things the template leaves to you, both of which validation will catch:
- **`PLUGIN_CODE`** must be unique per plugin. The template ships `Newp`; change it.
- **`isBusesLayoutSupported`** — if your `processBlock` indexes a channel by number
  (`getWritePointer(1)`), you must declare which layouts you accept, or a host may hand you a
  mono buffer and you will read off the end of it.

## Where to add things (the markers in the example)

- **A parameter** → `createParameterLayout()` in `PluginProcessor.cpp` (uncomment the example).
- **DSP setup** → `prepareToPlay()` (prepare `juce::dsp` objects, allocate buffers).
- **The processing** → `processBlock()` (read params, apply DSP; currently passthrough).
- **A control** → the editor: declare a `Slider` + its `SliderAttachment` in `PluginEditor.h`
  (attachment *after* the slider), configure them in the constructor, position in `resized()`.

## Next, by plugin type

- Parameter + simple DSP → [`01_gain.md`](01_gain.md)
- Per-channel processing → [`02_panning.md`](02_panning.md)
- Time-based / buffers → [`03_delay.md`](03_delay.md)
