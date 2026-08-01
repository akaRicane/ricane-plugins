# DelayPlugin

The first **time-based** plugin: output depends on past samples, not just the current one. That
one change is what makes it the most interesting plugin in `bank/` so far — it is the first with
state that must be sized from the sample rate.

| | |
|---|---|
| Folder | [`bank/DelayPlugin/`](../../bank/DelayPlugin/) |
| Formats | VST3, Standalone (AU too when validating) |
| `PLUGIN_CODE` | `Dela` |
| Classes | `DelayAudioProcessor`, `DelayAudioProcessorEditor` |
| Parameters | none yet |
| **Status** | **Scaffolded — passes audio through untouched. The DSP is not written yet.** |

Created with `./utils/new_plugin.sh`, so it currently is the annotated template with every
identifier renamed: it builds, loads and passes audio through, with `apvts` wired and markers
showing where things go. Nothing below the "What to build" heading exists yet.

## What to build

The theory, with a full reference implementation, is in
[`03_delay.md`](../knowledge/03_delay.md). The short version:

Record incoming samples into a ring buffer; read them back N samples later.

```
readHead = (writeHead - delaySamples + bufferSize) % bufferSize
```

The `+ bufferSize` before the `%` is not optional — C++ modulo returns negative values for
negative operands.

Suggested first parameter set: `DELAY_TIME` (seconds), then `FEEDBACK` and `MIX` as extensions.

## Traps this plugin is specifically for

This is the plugin that will exercise everything the repo has set up. Four things to get right,
each of which the tooling can catch:

**1. The buffer size depends on the sample rate.** `sampleRate * maxDelaySeconds` samples, so it
must be allocated in `prepareToPlay` — the sample rate isn't known before then. A buffer sized at
44.1 kHz and then run at 96 kHz is *the* classic delay crash, and it is exactly what
`./utils/validate.sh` sweeps for: 44100/48000/96000 × five block sizes, 15 combinations.

**2. `prepareToPlay` can be called again at any time.** Changing the rate mid-session re-allocates.
Always `clear()` after allocating — uninitialised memory is garbage, and garbage in a delay line
is an audible burst.

**3. Don't allocate in `processBlock`.** Resizing the delay buffer when the time parameter changes
is the tempting mistake; it allocates on the audio thread. Size the buffer for the *maximum* delay
once, and change only the read offset. `./utils/validate.sh -r enabled` catches violations.

**4. If you index channels by number, implement `isBusesLayoutSupported`.** The reference snippet
in `03_delay.md` is written channel-generically in its inner loop — keep it that way. Writing
`buffer.getWritePointer(1)` unconditionally is what segfaulted
[PannerPlugin](panner_plugin.md), and a host is entitled to hand you a mono buffer.

## Build and validate

```bash
./utils/build.sh -o DelayPlugin
./utils/validate.sh DelayPlugin        # then -s 10 once the DSP is in
```

Validate early — while it's still passthrough it should pass cleanly, which gives you a known-good
baseline. Any failure after that is something you just wrote.
