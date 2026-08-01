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
| Parameters | `DELAY_TIME` (0–2 s), `DRY_WET` (0–1) |
| **Status** | **Working single-tap delay. Passes pluginval at strictness 10.** |

A ring buffer records the dry input; the output crossfades between the live signal and the same
signal read back `DELAY_TIME` seconds earlier. No feedback yet, so you get exactly one echo. The
read head is fractional, interpolated, and smoothed — see [Why moving the delay-time knob
clicked](#why-moving-the-delay-time-knob-clicked).

`maxDelaySeconds` is a `static constexpr` on the processor, and *both* the parameter's upper bound
and the ring buffer's length derive from it. That's deliberate: those two numbers must agree, and
the first version had them typed separately (a 10-second range over a 1-second buffer), which is a
read past the end of the buffer.

## What to build next

The theory is in [`03_delay.md`](../knowledge/03_delay.md). Two extensions, in order of value:

- **`FEEDBACK`** — the missing ingredient for repeating echoes. One line: store the *mixed* result
  in the ring buffer instead of the dry input, scaled by the feedback amount. Keep the coefficient
  below 1.0 or the delay line diverges into runaway self-oscillation.
- **Modulating `DELAY_TIME` with an LFO** — now that the read head is fractional and interpolated,
  this is what turns a delay into a chorus (a few ms, shallow) or a flanger (under a ms, with
  feedback). The machinery is already in place.

## Traps this plugin is specifically for

This is the plugin that exercises everything the repo has set up. Four things to get right, each of
which the tooling can catch:

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
`isBusesLayoutSupported` here accepts mono→mono and stereo→stereo only: the delay is one
independent ring buffer per channel and does no up/down-mixing, so in must equal out.

## What went wrong writing it

Six bugs, and the pattern is worth more than the individual fixes.

**Reaching for a constant that isn't one.** `juce::AudioFormatReader::sampleRate` and
`juce::AudioDeviceManager::AudioDeviceSetup::bufferSize` look like global constants and are
*instance fields on unrelated classes* — `AudioFormatReader` reads audio files, and neither has
anything to do with a plugin's current rate. This doesn't compile ("invalid use of non-static data
member"), which is the good outcome. **The sample rate arrives exactly once, as the `prepareToPlay`
argument. Store it in a member; there is no other way to get it.**

**Wrapping the ring buffer on the wrong length.** The wrap used the host's block size where it
needed the ring buffer's length. Those are unrelated numbers — a few hundred samples versus
seconds — so the effective delay would have been capped at one block. The right-hand side of that
`%` is always `delayBuffer.getNumSamples()`.

**A sign error in the crossfade.** Written as `dry - coef * (dry + delayed)`; the algebra is
`dry*(1-coef) + delayed*coef` = `dry + coef*(delayed - dry)`. The bracket is a **difference**. With
the sum, `coef = 0` doesn't return the dry signal — it inverts and doubles it. Expanding the
crossfade by hand is where this class of bug lives; the two-term form is harder to get wrong.

**Parameter range wider than the buffer.** Covered above — the reason `maxDelaySeconds` is now one
constant feeding both.

**A parameter ID typo.** The editor attached to `"WET_DRY"`; the parameter is `"DRY_WET"`. These
strings are matched at *runtime* — a typo compiles cleanly and asserts when the editor opens. Worth
knowing that no compiler will help you here.

**Empty `resized()`.** Both sliders were constructed, styled and `addAndMakeVisible`'d, and would
have rendered as nothing at all: a component whose bounds are never set is 0×0. Layout lives in
`resized()`, never in `paint()`.

## Why moving the delay-time knob clicked

The first working version clicked whenever `DELAY_TIME` changed. That single symptom had **two**
independent causes, and fixing either alone leaves the other audible.

**1. The read head teleported.** `delaySamples` was computed once per block, so on the block where
the knob moved, the read position jumped — say from 4410 to 8820 — between one sample and the next.
The output waveform steps discontinuously, and a step *is* a click. Nothing about the click comes
from the delay being "wrong"; both positions are perfectly valid, it's the instant transition
between them that you hear.

**2. `delaySamples` was an `int`.** Even a slow, smooth sweep snaps from one whole sample to the
next, so you get a stream of tiny steps — the "zipper" noise under the big click.

The fix for (1) is `juce::SmoothedValue<float>`: `setTargetValue()` once per block, then
`getNextValue()` **once per sample**, so the read head slides instead of jumping. Two things to get
right there:

- Call `getNextValue()` **outside the channel loop.** Calling it per channel advances the ramp
  twice as fast in stereo and desyncs the two channels against each other.
- Use `setCurrentAndTargetValue()` in `prepareToPlay`, not `setTargetValue()`. Otherwise every
  session recall starts the delay at zero and swoops up to the saved value.

The fix for (2) falls out of (1): once the position is a `float`, the read head lands *between* two
stored samples, so blend them by the fractional part. Beware the low end — the clamp's floor is 1
sample, not 0, because below that the interpolation reaches for `delayBuffer[writeHead]`, which
hasn't been written yet this pass and still holds audio from a whole ring ago.

**The trade-off worth understanding:** a gliding read head is a *moving* read head, so it Doppler
shifts while it travels. That's why tape echoes bend in pitch when you change the time, and this
plugin now does the same. It's the sound most people want from a delay knob. If you want the delay
to retime *cleanly* instead, the alternative is to run two read heads — old position and new — and
crossfade between them over ~20 ms. No pitch bend, but two reads per sample and a brief moment
where you hear both delays at once.

## Build and validate

```bash
./utils/build.sh -o DelayPlugin
./utils/validate.sh -s 10 DelayPlugin              # passes
./utils/validate.sh -s 10 -r relaxed DelayPlugin   # passes — no allocation in processBlock
```

Use `-r relaxed`, not `-r enabled`: the strict mode fails on every plugin in this repo for reasons
that live inside JUCE. See [`tools/pluginval.md`](../tools/pluginval.md#--rtcheck-the-audio-thread-rule).
