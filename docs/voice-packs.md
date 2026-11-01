# Reminder voices: the plan and why

This document records the decision behind Lujayn's optional natural voices, so
the next contributor does not re-litigate it. It also states plainly what is
verified and what is not.

## The short version

Lujayn keeps Android's built-in text-to-speech engine as the default. On top of
that it offers two optional, downloadable, fully offline neural voices. The
engine is [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache-2.0),
which runs ONNX speech models on the phone's CPU through FFI with no network
access at runtime.

| Pack | Model | Download | Unpacked | Voices | Licence |
|---|---|---|---|---|---|
| Light | Kitten Nano v0.1 (fp16) | 25.6 MB | 40 MB | 8 (4 female, 4 male) | Apache-2.0 |
| Natural | Kokoro v0.19 (int8) | 98.5 MB | 151 MB | 11 (7 female, 4 male) | Apache-2.0 |

Both are inside the 200 MB ceiling the product asked for. Every size in this
table was measured by downloading the published archive and unpacking it, not
estimated. Both archives were also checksummed, and both matched the SHA-256 in
the catalog.

Both packs ship their model under a non-default file name
(`model.fp16.onnx` and `model.int8.onnx`). That is recorded per pack in the
catalog. Getting it wrong would fail silently at load time, so if a pack is ever
upgraded, inspect the archive before trusting the file names.

## Why not ElevenLabs

ElevenLabs is a cloud service. Using it would mean sending reminder text — the
most personal content in the app — to a third party, and reminders would stop
working without a connection. That contradicts the product's first rule. It is
useful only as a quality reference, which is why Kokoro was chosen: it is the
best-sounding open model that still runs offline on a phone.

## Why these two packs

- **Light (Kitten Nano)** exists for people on expensive or slow mobile data.
  25 MB is a download someone will actually accept on a prepaid plan.
- **Natural (Kokoro)** exists for quality. Kokoro is a 82M-parameter model and
  sounds markedly more human than Piper, which was the first candidate
  considered. Its int8 build is 98.5 MB.
- Piper was rejected as the *only* option because its medium voices are around
  60 MB and its quality is clearly below Kokoro. It remains a reasonable third
  pack later if a smaller download is needed.

## Speaker maps are not guesses

A wrong speaker id means a voice labelled "Female" that sounds male, or a name
that belongs to someone else. The ids in `lib/features/voice/data/voice_catalog.dart`
come from the upstream sherpa-onnx documentation:

- Kokoro v0.19: <https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html>
- Kitten Nano v0.1: <https://k2-fsa.github.io/sherpa/onnx/tts/all/English/kitten-nano-en-v0_1.html>

If a pack is ever upgraded, re-read those pages rather than assuming the order
is unchanged.

## Integrity

Each pack has a published SHA-256 from the upstream GitHub release. The installer
verifies the download against it and throws the file away on a mismatch. That
matters because a corrupted model would otherwise fail in a confusing way much
later, at speaking time.

## How an install works

1. Download to `<app support>/voices/<pack>.part`, streaming to disk so a
   100 MB file never sits in memory.
2. Hash the file with SHA-256 and compare it with the catalog.
3. Decompress bzip2 to a temporary `.tar` file, then unpack the tar into a
   staging directory. This runs on a background isolate so the interface keeps
   responding.
4. Write a marker file, then rename the staging directory to the pack's real
   name.

The rename is the only moment the pack becomes visible. A cancelled download, a
bad checksum, a corrupt archive, or a full disk therefore leaves no
half-installed pack that the app could later try to speak with. Every failure
path is covered by `test/voice_install_test.dart`, which builds a real
`.tar.bz2` in memory and runs the whole pipeline.

## Storage location

`getApplicationSupportDirectory()`, not the cache directory. Android may clear
the cache at any time; losing a 100 MB voice the user paid data to download
would look like the app forgot a setting.

## Privacy

- The download is a plain HTTPS GET of a public file. No account, token, device
  id, or reminder text is involved.
- Speech is generated on the device. Reminder text never leaves it.
- The app works fully without any pack; the device engine is always available.

## What is verified, and what is not

Verified here, with real commands:

- The catalog's invariants (voice count, both genders, unique ids, size budget,
  checksum format) — `test/voice_catalog_test.dart`.
- The whole install pipeline: progress reporting, checksum rejection, corrupt
  archive rejection, atomic install, removal — `test/voice_install_test.dart`.
- Selection persistence and the fallback to the device voice when a pack is
  removed — `test/voice_settings_screen_test.dart`.
- The published archive sizes and SHA-256 values against the upstream release.

**Not verified: actually speaking.** The engine adapter (sherpa-onnx
initialisation, generation, and audio playback) is not written yet, and nothing
in this feature has run on a physical Android device. Do not describe the voices
as working until both are done and tested on hardware.

## Remaining work

1. Add `sherpa_onnx` and a player, and implement the engine adapter behind the
   existing `ReminderSpeechService` contract, selecting the installed pack when
   one is chosen and falling back to the device engine otherwise.
2. Decide the audio-focus behaviour when a reminder speaks over music.
3. Measure generation latency on a mid-range phone; Kokoro runs at roughly 0.3×
   real time on a Raspberry Pi 4, and a phone may be similar. If a short
   reminder takes several seconds to start, generate ahead of the alert.
4. Physical-device test matrix entry for both packs: download over Wi-Fi,
   download over mobile data, install with the screen off, remove, and speak.
