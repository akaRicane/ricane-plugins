# Testing with pluginval

How to check a plugin behaves itself before a host — or a user — finds out it doesn't.

---

## The problem it solves

You write a plugin. It works in your Standalone build. You load it in your DAW — fine. Someone
else loads it in Reaper at 96 kHz with a 32-sample buffer, automates a knob, saves the project,
reopens it, and it crashes or comes back with the wrong values.

That gap is the whole problem. **Your plugin is a library that a host drives, and every host
drives it differently.** The host picks your sample rate, your buffer size, when `prepareToPlay`
is called and how many times, on which thread, and in what order. The JUCE API lets a host do far
more than any single DAW you happen to test in actually does.

[pluginval](https://github.com/Tracktion/pluginval) is a **deliberately hostile fake host**. It
does all the legal-but-unusual things real hosts do, and checks you survive.

It does **not** know what your plugin is supposed to sound like. It will never catch "my panner
is 3 dB too quiet". It catches "my plugin crashes when the buffer size changes" — a different and
much nastier class of bug, because that one is invisible until it happens on someone else's
machine.

---

## Running it

```bash
./utils/validate.sh                 # interactive: pick a plugin from a menu
./utils/validate.sh GainPlugin      # validate one plugin at strictness 5
./utils/validate.sh -s 10 GainPlugin  # maximum strictness
./utils/validate.sh --help          # every option
```

Exit code `0` means every test passed. **Trust the exit code, not your reading of the log** — the
output is a long, deliberately boring list of `Starting tests in: X` / `Completed tests in X`, and
skimming it is how you miss things.

The first run on a plugin is slow: it configures a separate `build-pluginval/` tree with
`-DENABLE_PLUGINVAL=ON`, which builds pluginval itself — a whole JUCE application, ~280 MB and
several minutes. Later runs reuse it. The normal `build/` tree is untouched, so everyday builds
stay fast.

---

## What it actually tests

These are the test groups from a real GainPlugin run:

| Test group | What it's really checking |
|---|---|
| Plugin info | Name, format, channel counts are sane and self-consistent |
| Editor | Open/close the GUI repeatedly without leaking or crashing |
| Audio processing | Run audio at **every** sample rate × block size combination |
| Plugin state | `getStateInformation` / `setStateInformation` round-trip correctly |
| Automation | Hammer parameters while audio is running |
| Editor Automation | Same, with the GUI open — catches editor/processor races |
| Automatable Parameters | Every parameter behaves the way a parameter should |
| auval | Apple's own AU validator, run for you (macOS) |
| Locale | Your plugin doesn't corrupt number formatting process-wide |
| Bus tests | Enable/disable/rearrange buses, restore defaults |
| Parameter thread safety | *(strictness 6+)* parameters touched from several threads |
| Fuzz parameters | *(strictness 6+)* random values slammed in at random times |

### The sweep that catches most bugs

```
Testing with sample rate [48000] and block size [256]
Testing with sample rate [96000] and block size [64]
Testing with sample rate [96000] and block size [1024]
```

Default is 44100/48000/96000 × 64/128/256/512/1024 — **15 combinations**. Anything you size in
`prepareToPlay` (a delay line, a filter's history, a smoothing ramp) gets built and rebuilt under
all of them.

This is why validation earns its keep the moment you write a delay: a buffer sized for one sample
rate and used at another is *the* classic beginner crash, and it is completely invisible until
someone changes the rate.

### The buses thing

From that same stereo gain plugin's run:

```
Named layouts: Mono, Stereo, LCR, Quadraphonic, 5.0 Surround, 5.1 Surround, 7.0, 7.1
Total candidate layouts to test: 5
Layouts tested: 5, accepted by setBusesLayout: 5
```

You wrote a stereo plugin; pluginval asked it to run in 5.1 and 7.1, and accepted every answer it
gave. That's `isBusesLayoutSupported` doing real work you probably never thought about.

**This is not hypothetical — it is the first bug validation found in this repo.** PannerPlugin
segfaulted here on its very first run:

```
Starting tests in: pluginval / Bus layout processing...
Total candidate layouts to test: 5
pluginval received Segmentation fault: 11, exiting immediately
```

The cause: it never implemented `isBusesLayoutSupported`, so it inherited JUCE's default —

```cpp
virtual bool isBusesLayoutSupported (const BusesLayout&) const { return true; }
```

— which tells the host *every* layout is fine. Meanwhile `processBlock` did:

```cpp
auto* dataL = buffer.getWritePointer(0);
auto* dataR = buffer.getWritePointer(1);   // assumes channel 1 exists
```

Host asks for mono → plugin says yes → buffer arrives with one channel → `getWritePointer(1)`
runs off the end. The fix is to say what you actually support:

```cpp
bool PannerAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const auto stereo = juce::AudioChannelSet::stereo();
    return layouts.getMainInputChannelSet()  == stereo
        && layouts.getMainOutputChannelSet() == stereo;
}
```

**Takeaway: if `processBlock` indexes a channel by number, you owe the host an
`isBusesLayoutSupported`.** Rejecting a layout isn't a limitation — it's how the host learns to
hand you a buffer you can handle. And note this never once misbehaved in the Standalone build,
which always gave it stereo.

---

## Strictness levels

One number, 1–10:

- **1–4** — quick smoke tests: does it load, make sound, and not immediately crash.
- **5** — the default, and the number that matters. pluginval's recommended *minimum* for host
  compatibility. Treat "passes at 5" as the bar for "I can give this to someone".
- **6–9** — longer runs, parameter fuzzing, thread-safety tests.
- **10** — everything, most thorough.

**Develop against 5, ship against 10.** Level 5 is fast enough to run often; level 10 is where the
once-in-a-thousand race hides and is slow enough that you won't want it in your inner loop.

---

## `--rtcheck`: the audio-thread rule

macOS/Linux only, and the most educational part of the tool.

**The rule:** `processBlock` runs on a real-time audio thread. If it takes too long you get an
audible click — not a slowdown, a *dropout*. So anything that can take unbounded time is
forbidden there:

- allocating or freeing memory — `new`, `delete`, `malloc`, `std::vector::resize`,
  most `juce::String` operations
- taking a lock or mutex
- file or network I/O
- logging

The insidious part: **your plugin works fine while doing all of these.** An allocation usually
takes microseconds. It only bites when the allocator hits a slow path, on someone else's machine,
under load. You cannot find this by listening.

rtcheck instruments the process and intercepts the forbidden calls:

```
Real-time violation: intercepted call to real-time unsafe function calloc
in real-time context! Stack trace:
 rtc::log_function_if_realtime_context(char const*)
  log_function_if_realtime_context_and_enabled(rtc::check_flags, char const*)
   wrap_calloc
```

Three modes, via `-r` / `--rtcheck`:

- `disabled` — off.
- `relaxed` *(default)* — ignores the **first** processed block. Most plugins legitimately
  allocate on the first call, as JUCE lazily initialises things and thread-locals get set up.
- `enabled` — strict; flags the first block too. Expect noise from framework startup here, so
  read its findings with judgement rather than treating every hit as your bug.

**`-r enabled` currently fails for every plugin in `bank/`,** including one as simple as
GainPlugin. It always dies in the `Automation` test group with a `calloc` whose stack trace is
entirely inside JUCE:

```
wrap_calloc
 _malloc_type_calloc_outlined
  dyld::ThreadLocalVariables::instantiateVariable(...)
   _tlv_get_addr
    juce::setValueAndNotifyIfChanged(juce::AudioProcessorParameter&, float)
     juce::JuceVST3Component::processParameterChanges(...)
```

That's macOS lazily allocating storage for a **thread-local variable** the first time JUCE's VST3
parameter path touches it on the audio thread. It's one allocation, in framework code, and nothing
you write in `processBlock` can prevent it.

**So `relaxed` is the meaningful gate, not a weaker one.** It skips exactly the first block, which
is where this startup noise lives, while still catching every allocation in steady-state
processing. Use `-r enabled` only when you're chasing a specific suspicion and are prepared to read
past the JUCE frames — a plain "FAILED" from it means nothing on its own.

---

## When something fails

1. **Read which test group failed, and at which sample rate / block size.** That alone usually
   names the bug.
2. **Reproduce it fast** — re-run with `--verbose`, and narrow the sweep by calling the binary
   directly with `--sample-rates 96000 --block-sizes 64`.
3. **Get a stack trace** — `./utils/validate.sh -i <plugin>` passes `--validate-in-process`.

That last one deserves an explanation. By default pluginval **forks a child process** to host your
plugin, so when your plugin segfaults, pluginval survives and reports it cleanly. Great for CI,
useless for debugging, because your debugger is attached to the parent. `-i` runs the plugin in
pluginval's own process instead, so a crash stops where you can see it — at the cost of taking
pluginval down with it.

**Intermittent failures** are usually order-dependent: one test leaves state that breaks another.
Shake those out with `--repeat 3 --randomise`.

---

## How it's wired in

- `tools/pluginval/` — the validator, a git submodule tracking `develop`.
- `cmake/Pluginval.cmake` — the shared CMake glue. Each plugin calls `pluginval_formats()` before
  `juce_add_plugin` and `pluginval_enable(<Target>)` after it.
- `utils/validate.sh` — the wrapper you actually run.

Everything is inert unless you configure with `-DENABLE_PLUGINVAL=ON`, which `validate.sh` does
for you in the separate `build-pluginval/` tree.

Two quirks of pluginval's CMake integration are worth knowing, because neither fails helpfully:

- **It hardcodes `<Project>_AU` as the macOS validation target** and calls `get_target_property`
  on it without checking it exists. That's why `pluginval_formats()` appends `AU` to `FORMATS`
  when validation is on — without it, configuring dies with a bare "non-existent target" error.
- **`PLUGINVAL_ENABLE_RTCHECK` only defaults ON when pluginval is the top-level project.** As a
  dependency it is silently off, so `cmake/Pluginval.cmake` sets it explicitly. Otherwise
  `--rtcheck` would appear to work while doing nothing.

The embedded Steinberg VST3 validator is disabled (`PLUGINVAL_VST3_VALIDATOR=OFF`) because it
makes CMake fetch and build the entire VST3 SDK. Turn it on in `cmake/Pluginval.cmake` if you want
VST3 spec-conformance checks.

> **Licensing:** pluginval is **GPLv3**, unlike this repo's MIT code. Using it to validate your
> plugin locally is fine. Never ship a binary that combines the two.

---

## What it is not

It won't verify your DSP is correct, won't measure latency or CPU, won't tell you your GUI looks
wrong, and passing it doesn't guarantee every DAW will love you.

It means you haven't violated the contract hosts rely on. That's a floor, not a ceiling — but it's
a floor most first plugins fall straight through.
