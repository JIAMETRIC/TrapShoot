# Security

A local‑first app with no accounts has a small attack surface. This is what is left, mapped to the OWASP Mobile Top 10
(2024), and what the code does about it.

| OWASP Mobile | Applies? | What we do |
|---|---|---|
| M1 Improper credential usage | No credentials | There are no passwords, tokens or API keys in the app. The Open‑Meteo API needs none. The old Supabase anon key leaves with the Web folder. Nothing to hash, nothing for the Keychain. |
| M2 Inadequate supply chain | Low | Zero third‑party dependencies. Local Swift packages only. CI builds from source. |
| M3 Insecure authentication / authorization | None | No server, no sessions. If coach sharing ever arrives it is an export the shooter sends, or a signed, expiring share link (ADR‑014), never a login wall. |
| M4 Insufficient input/output validation | Yes | Every import goes through `Validation.sanitized` then `Validation.issues`: trimmed and capped text, clamped conditions, impossible times dropped, structural problems reported. `RoundDocument` is tolerant to wrong types. CSV cells that start with `= + - @ TAB` get an apostrophe so a note can never run as a spreadsheet formula. File names from the shooter are stripped to `[A-Za-z0-9_-]`. |
| M5 Insecure communication | Yes | HTTPS only; App Transport Security defaults, no exceptions. The weather session has no cache and no cookies. No pinning (public weather data). |
| M6 Inadequate privacy controls | Yes | Nothing leaves the device except latitude/longitude rounded to 4 decimals to Open‑Meteo, once, when the shooter allows location. Logs use `privacy: .private` for anything that is not a count or a state. The support bundle contains no round data. Privacy manifest says "no tracking, no collected data". |
| M7 Insufficient binary protections | Low | No secrets to hide. Standard release builds; no custom obfuscation. |
| M8 Security misconfiguration | Yes | No background modes, no custom URL schemes handling data, file sharing on (by design: recordings in Files), `UIFileSharingEnabled` exposes only the Documents folder. |
| M9 Insecure data storage | Yes | Store and recordings are protected with `completeUntilFirstUserAuthentication` (encrypted at rest, readable after first unlock so timing works). Included in device backups, which are encrypted by iOS when the user enables it. No data in `UserDefaults` beyond settings. |
| M10 Insufficient cryptography | None | No custom crypto. Platform encryption only. |

## Input validation rules (TrapCore `Validation`)

- Dates `yyyy-MM-dd`, times `HH:mm`, station 1…5, scheme 1…10, session ≥ 1.
- Text fields ≤ 200 characters, notes ≤ 2,000, NUL bytes removed, whitespace trimmed.
- Temperature −50…60 °C, humidity 0…100 %, shot times 0…5 s and finite, 2nd shot after the 1st.
- Station quota (2 right, 1 straight, 2 left) checked and reported, never silently changed.

## Threats considered and accepted

- A shooter with a jailbroken phone can read their own data: it is their data.
- A malicious backup file: it is parsed with `JSONSerialization`, every row validated, unknown rows skipped, the import
  is one transaction and the report lists rounds with issues. Worst case is a bad round the shooter can delete.
