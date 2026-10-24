# Detector regression set

Real range recordings with known call and shot times. `DetectorRegressionTests` (in `Packages/ShotTimer`) feeds
every fixture here through `FileAnalyzer`, which is the live `AudioDetector` fed from a file, and fails if a time is
off by more than the tolerance (7 ms by default, from the Phase 4 plan). This folder is what makes CLAUDE.md rule 1
("never change the detector without a fixture-based regression run") possible.

The folder ships empty. Until the first fixture lands, the test skips with a reason and the synthetic tests in the
same file stand in for it.

## One fixture = two files

```
Tools/detector-fixtures/
  2026-10-18-dji-s3.m4a      mono, 48 kHz, AAC (or .caf / .wav); the audio as the iPhone heard it
  2026-10-18-dji-s3.json     the expected times
```

```json
{
  "name": "2026-10-18 mic test, DJI Mic Mini 2, station 3",
  "audio": "2026-10-18-dji-s3.m4a",
  "receiver": "DJI Mic Mini 2",
  "notes": "two shooters on the line; the neighbour's shots at 41 s and 43 s must be ignored",
  "settings": { "callDb": 85, "shotDb": 112 },
  "toleranceMs": 7,
  "targets": [
    { "firstMs": 612, "secondMs": 1034 },
    { "firstMs": 587, "secondMs": null }
  ]
}
```

- `targets` are in order of appearance. `firstMs` is call onset to 1st shot; `secondMs` call onset to 2nd shot or
  `null` when there was one shot.
- `settings` lists only what differs from the app's defaults (`TimerSettings`): `callDb`, `shotDb`, `gateDb`,
  `secondWinMs`, `offset`.
- `receiver` and `notes` are for people. Say which receiver, and anything that should be rejected.

## Making one from a range video or a recording

The owner has nine range videos and the 18 October microphone test. `make-fixture.sh` turns a video or any audio
file into the mono 48 kHz `.m4a` the detector expects and writes a JSON skeleton to fill in:

```bash
Tools/detector-fixtures/make-fixture.sh ~/Videos/range-2026-09-12-s3.mp4 2026-09-12-s3 "DJI Mic Mini 2"
```

Then the expected times. Open the `.m4a` in Audacity (or any editor with a sample-accurate cursor), find each
target: the call onset is where the voice first rises out of the background (not the loudest point), the shots are
the sharp broadband spikes. Write `firstMs = shot1 - call`, `secondMs = shot2 - call` in milliseconds into the JSON.
Round to the millisecond. Two people reading the same file should agree within 2 to 3 ms; if they do not, the
recording is not a good fixture.

The in-app alternative: Settings → About → debug screen → "Time a recording" runs the same `FileAnalyzer` on a file
from the Files app and shows what the detector heard, which is a quick way to sanity-check the JSON before committing.

## Rules

- Never edit a fixture's times to make the test pass. A failing fixture means the detector changed or the fixture is
  wrong; both are decided by listening, not by editing numbers.
- Never commit a recording with a conversation in it that the people on it would not want public; trim to the
  targets. Round data is not in these files.
- Keep each file under 10 MB (a 25-target round is about 4 MB as AAC). Git LFS is not set up; the repository is
  small on purpose.
- The regression set runs in CI (`ShotTimer tests`) and in `/mac-build`. `/mac-release` runs it on the Release
  configuration before any upload.
