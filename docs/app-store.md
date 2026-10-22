# App Store publishing

What is in the code, what is in App Store Connect, and the order to do it in.

## In the repository

| Item | Where | Status |
|---|---|---|
| Bundle id `com.mtajudeen.trapshooterpro`, display name TrapShoot, category Sports, iOS 17, iPhone + iPad | `project.pbxproj` | done |
| Microphone and location usage strings | `project.pbxproj` (`INFOPLIST_KEY_…UsageDescription`) | done; keep accurate |
| Privacy manifest (no tracking, no collected data, required‑reason APIs) | `TrapShooterPro/PrivacyInfo.xcprivacy` | done |
| App icon 1024 | `Assets.xcassets/AppIcon` | present; redo in the B&W system before submission |
| Launch screen | generated (`UILaunchScreen_Generation`) | done |
| Versioning | `MARKETING_VERSION` (shooter‑visible, e.g. 8.0.0), `CURRENT_PROJECT_VERSION` (build, increases every upload) | 8.0.0 (1) since the native app (22 October 2026); 7.0.7 (8) was the last hybrid build |
| Archive and upload | `Scripts/archive.sh`, `ExportOptions.plist` | done |
| Export compliance | App Store Connect → App Information → "Uses non‑exempt encryption: No" (only HTTPS to a public API) | set once per app |

## App Privacy answers (nutrition label)

Everything stays on the device. Answer **"Data Not Collected"**. Location is used once for the weather fill and is
not stored or sent anywhere except as latitude/longitude to Open‑Meteo's public API, rounded to four decimals; that is
not "collection" by Apple's definition because it is not linked to the user or retained. State this in the review notes.

## Review notes (paste into App Store Connect)

> TrapShoot is a shot timer and scorecard for Olympic Trap, an ISSF/Olympic shotgun discipline. The microphone is used
> only while the shooter taps Start, to time the voice call and the shots of a clay target; nothing is uploaded. No account
> is needed; all data stays on the device and can be exported by the user as CSV, PDF or a backup file. Location is
> optional and used once per round to pre‑fill the weather from Open‑Meteo. To test the timer without a range: on
> Record, type any range name, pick Field 1 and Sky, enter a temperature and humidity (or tap Weather), tap Start round;
> then on Timer tap Start timer, say "pull" loudly and clap twice within a second. The readout shows the call‑to‑clap
> times and the Record tab asks for the target's direction and result.

## Listing

- **Name**: TrapShooterPro (30 chars max). **Subtitle**: Olympic Trap shot timer & scorecard.
- **Keywords**: trap,olympic trap,shotgun,clay,shooting,timer,scorecard,ISSF,bunker,score
- **Description**: lead with the timer accuracy (call to shot in milliseconds, external receivers such as DJI Mic Mini 2),
  then the 25‑target scorecard with the station rule, break distance, analysis by trap and station, and exports. Say
  plainly: no account, works offline, your data stays on your phone.
- **Screenshots**: 6.9" (iPhone 17 Pro Max) and 13" iPad required; light and dark; Record, Timer, Analysis, Schemes.
- **Age rating**: answer the questionnaire honestly; sport shooting with no violence content rates 4+.
- **Support URL and privacy policy URL**: `docs/support.md` and `docs/privacy.md` in this public repository
  (`https://github.com/JIAMETRIC/TrapShooterPro/blob/main/docs/privacy.md`)..

## Order of work

1. Apple Developer Program membership; create the App ID and the app record in App Store Connect with the bundle id.
2. `Scripts/archive.sh` → TestFlight internal testing (you), then external testing (Yugan, Khalid, Pittu). External
   TestFlight needs a short beta review; the review notes above work for it too.
3. Fix what the range finds. Run the detector regression set on the final build.
4. Screenshots, listing text, privacy answers, export compliance.
5. Submit for review. Expect questions about the microphone; the notes answer them.

## Accessibility and quality gates before submission

- Dynamic Type up to accessibility sizes on Record and Timer without clipped controls.
- VoiceOver labels on every target entry button ("Station 3, target 11, left", "Hit first barrel").
- Dark mode on every screen. Reduce Motion respected (no spring overshoot).
- 44 pt targets everywhere; the NO TARGET bar and result buttons at least 56 pt tall for gloved hands.
- No crash with the microphone denied, location denied, Low Data Mode, Airplane Mode, disk nearly full.
