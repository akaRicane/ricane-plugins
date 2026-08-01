# The scripts in `utils/`

Four scripts, one job each. All are run from the repo root and work from any working directory.
The three that operate on an existing plugin accept it the same way:

```
GainPlugin                     a folder name inside bank/
bank/GainPlugin                a path with the bank/ prefix
documentation/example_plugin   any directory containing a CMakeLists.txt
```

Run any of them with no arguments for an interactive menu, or `--help` for full options.

---

## `new_plugin.sh` — scaffold a new plugin

```bash
./utils/new_plugin.sh                # asks for everything
./utils/new_plugin.sh DelayPlugin    # name given, still confirms the rest
```

Copies [`example_plugin/`](../example_plugin) into `bank/`, renames every identifier in it, and
registers the new build with the editor. Interactive by design: four questions, each with a
default deduced from the name, so the usual answer is four presses of Enter.

| Question | Default for `DelayPlugin` | Becomes |
|---|---|---|
| Folder & target name | — | the folder, `project()`, and `juce_add_plugin()` target |
| Class prefix | `Delay` | `DelayAudioProcessor`, `DelayAudioProcessorEditor` |
| Product name | `Delay Plugin` | `PRODUCT_NAME` — what the DAW shows |
| `PLUGIN_CODE` | `Dela` | the 4-char plugin ID |

It refuses to continue on a name that isn't a valid CMake target, a folder that already exists,
or a **`PLUGIN_CODE` already used by another plugin** — it scans every `CMakeLists.txt` in `bank/`
plus the template, and lists what's taken. That last check exists because PannerPlugin once
shipped carrying the template's `Newp`, colliding with `example_plugin`.

Two things it does that are easy to forget by hand:

- **Renames the classes to the convention the rest of `bank/` uses.** The template declares
  `NewPluginProcessor`/`NewPluginEditor`, but GainPlugin and PannerPlugin use
  `<Prefix>AudioProcessor`/`<Prefix>AudioProcessorEditor`. The script generates the latter.
- **Adds the build to `.vscode/settings.json`**, so IntelliSense resolves `juce::` in the new
  files. Reload the window afterwards. If the file is missing it says so and carries on.

It never overwrites an existing plugin and never builds. Afterwards it prints what to do next,
including the documentation it deliberately does **not** write for you.

---

## `build.sh` — build a plugin

```bash
./utils/build.sh                 # interactive: pick from a menu
./utils/build.sh GainPlugin      # build one plugin
./utils/build.sh -o GainPlugin   # build, then open the Standalone
./utils/build.sh -c GainPlugin   # force a re-configure first
```

Configures `<plugin>/build/` on the first run only, then builds every run.

Use `-c` when you have **changed CMake options, added a source file, or want
`compile_commands.json` regenerated**. Adding a `.cpp` to `target_sources` without re-configuring
is a common way to get a confusing "undefined symbol" link error.

Outputs:
- Standalone → `<plugin>/build/<Target>_artefacts/Standalone/`
- VST3 → installed to `~/Library/Audio/Plug-Ins/VST3/` (restart your DAW to pick it up)

---

## `open.sh` — launch a built Standalone

```bash
./utils/open.sh GainPlugin       # quit any stale instance, then launch
./utils/open.sh -t GainPlugin    # run in this terminal
./utils/open.sh -q GainPlugin    # only quit a running instance
```

**This never builds.** It finds an already-built `.app` and runs it, which makes it fast when you
just want to look at the thing again.

It always quits a running instance first, so you are never staring at a stale build wondering why
your change did nothing.

`-t` is the one worth remembering: it runs the executable inside the bundle directly, so
`DBG()` and `std::cout` land in your terminal instead of vanishing. Ctrl-C quits. Without it the
app is launched detached and you get no output at all.

---

## `validate.sh` — run pluginval

```bash
./utils/validate.sh GainPlugin           # strictness 5, relaxed rtcheck
./utils/validate.sh -s 10 GainPlugin     # maximum strictness
./utils/validate.sh -i GainPlugin        # in-process, for debugging a crash
```

| Flag | Meaning |
|---|---|
| `-s, --strictness <1-10>` | How hard to push. 5 is the default and the compatibility baseline; 6+ adds fuzzing |
| `-r, --rtcheck <mode>` | `relaxed` (default), `enabled`, `disabled` — audio-thread allocation checks |
| `--repeat <n>` | Run the suite n extra times |
| `--randomise` | Shuffle test order each repeat; with `--repeat`, finds order-dependent bugs |
| `-i, --in-process` | Don't fork a child process, so a debugger stops in your code |
| `-c, --configure` | Force a re-configure of the validation build tree |

Exit code 0 means every test passed. **Trust the exit code over reading the log** — the output is
a long, deliberately boring list of test groups.

This one uses a **separate `build-pluginval/` tree**, because enabling validation builds pluginval
itself: a whole JUCE application, ~300 MB and several minutes on first run. Your normal `build/`
tree is untouched, so everyday builds stay fast. Delete `*/build-pluginval/` any time to reclaim
the space; the next run rebuilds it.

Full guide: [`pluginval.md`](../tools/pluginval.md).

---

## Conventions if you add a script

The three share a shape worth copying:

- `set -euo pipefail` at the top.
- Paths derived from the script's own location, never the working directory:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  ```
- A `usage()` heredoc, reachable with `-h`/`--help`.
- The same `resolve_plugin` / `list_plugins` pair, so every script accepts plugins identically.
- Flags parsed in any order, with at most one positional argument.
- Errors to stderr, prefixed `error:`, followed by a `hint:` line where there's an obvious fix.
