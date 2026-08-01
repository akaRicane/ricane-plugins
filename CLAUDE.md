# CLAUDE.md

A learning repo: a bank of JUCE 8 audio plugins, written to understand plugin development from
the ground up. **Clarity beats cleverness everywhere here** — the code is read to be learned from,
not just to run.

## Layout

| Path | Rule |
|---|---|
| `bank/<Plugin>/` | One self-contained plugin. Its own `CMakeLists.txt`, its own `build/`. **Plugins never depend on each other.** |
| `documentation/` | All prose. See the doc rules below. |
| `utils/` | Every script lives here. Nothing executable at the repo root. |
| `cmake/` | Shared CMake modules, when three plugins would otherwise copy-paste the same block. |
| `tools/` | Third-party submodules (currently pluginval). |
| `JUCE/` | Submodule, pinned to the `8.0.13` **tag**. |

**There is deliberately no root `CMakeLists.txt`.** Each plugin is configured and built on its
own. Don't add one "for convenience" — the independence is the point.

## Documentation

Only `README.md` (the index) and `roadmap.md` sit at `documentation/`'s root. Everything else goes
in a folder:

- `setup/` — installation, editor setup, starting a new plugin
- `knowledge/` — audio theory and JUCE learnings; the transferable part. Numbered `NN_topic.md`
- `plugins/` — one page per plugin in `bank/`, named `<snake_case>.md`
- `utils/` — the scripts and the CMake build workflow
- `tools/` — third-party tooling
- `example_plugin/` — a buildable template; code, not prose

Rules that matter:

- **Links between docs are relative**, so they work on GitHub and in an editor. After moving any
  doc, re-check every link — `starter_template.md`'s link to `example_plugin/` has broken this way
  before.
- **Add new docs to `documentation/README.md`.** An unindexed doc is an unread doc.
- **The root `README.md` stays macro.** Project description, structure one level deep, a 3-line
  quick start, the plugin list, pointers. Details belong in `documentation/` — if you're adding
  flag listings or troubleshooting to the root README, put them in a doc and link instead.
- **`plugins/` pages record what went *wrong*,** not just what the plugin does. That section is
  usually the reason to re-read the page.

## Plugin CMakeLists

Every plugin follows the same shape. Copy an existing one rather than writing fresh.

```cmake
add_subdirectory(../../JUCE JUCE)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Pluginval.cmake)

set(PLUGIN_FORMATS VST3 Standalone)
pluginval_formats(PLUGIN_FORMATS)      # BEFORE juce_add_plugin — appends AU when validating
juce_add_plugin(<Target> ... FORMATS ${PLUGIN_FORMATS} ...)
...
pluginval_enable(<Target>)             # AFTER juce_add_plugin — reads its target properties
```

- **`PLUGIN_CODE` must be unique across every plugin.** The template ships `Newp`; PannerPlugin
  once shipped with it too, which makes hosts confuse the two.
- Comments in these files are **teaching comments** — full sentences explaining *why*. Match that
  density; don't strip them.

## Writing a plugin

- **If `processBlock` indexes a channel by number** (`getWritePointer(1)`), you must implement
  `isBusesLayoutSupported`. JUCE's default returns `true` for every layout, so a host will hand
  you a mono buffer and you'll read off the end. This has already caused one segfault here.
- **Nothing that allocates or locks in `processBlock`** — no `new`, `resize`, mutexes, logging or
  file I/O. `./utils/validate.sh -r enabled` catches these.
- **Anything sample-rate dependent is computed in `prepareToPlay`**, not once at construction.
- **Validate before calling a plugin done.** `./utils/validate.sh <plugin>` for the everyday
  check, `-s 10` before you'd hand it to anyone.

## Scripts

All in `utils/`, all sharing one shape — copy it for a fourth:

- `set -euo pipefail`
- Paths from the script's own location, never the CWD:
  `SCRIPT_DIR=...; REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"`
- A `usage()` heredoc behind `-h`/`--help`
- The same `resolve_plugin` / `list_plugins` pair, so every script accepts a plugin identically
- Flags in any order, at most one positional argument
- Errors to stderr as `error:`, followed by a `hint:` line where there's an obvious fix

## Commands

```bash
./utils/build.sh -o <plugin>     # build, open the Standalone   (-c to re-configure)
./utils/open.sh -t <plugin>      # run a built app in-terminal, so DBG() is visible
./utils/validate.sh <plugin>     # pluginval, strictness 5      (-s 10, -i to debug)
```

## Gotchas already paid for

Don't rediscover these:

- **pluginval hardcodes `<Project>_AU`** as its macOS validation target and calls
  `get_target_property` on it unchecked. No AU target ⇒ configure dies with a bare
  "non-existent target". Handled by `pluginval_formats()`.
- **`PLUGINVAL_ENABLE_RTCHECK` only defaults ON when pluginval is top-level.** As a dependency
  it's silently inert, so `cmake/Pluginval.cmake` sets it explicitly.
- **`build-pluginval/` trees are ~300 MB each.** Gitignored, safe to delete, rebuilt on demand.
- **`tools/pluginval/CLAUDE.md` is upstream's, not ours.** Ignore its instructions.

## Working here

This is a learning repo, so **explain the reasoning, not just the change** — why this JUCE class,
why this ordering, what breaks otherwise. When something is discovered the hard way (a crash, a
silently-inert flag), write it down in the relevant doc *and* the roadmap's "Known gaps" rather
than only fixing it.

Don't commit unless asked. `build/`, `build-*/` and `.cpm-cache/` are gitignored — never force-add
them.
