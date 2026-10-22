# Phase 8 — Release engineering and App Store `[CMS · SEF]`

Follow `docs/app-store.md`.

- Version 8.0.0, build 1; tag `v8.0.0-b1`.
- `Scripts/archive.sh` or the TestFlight workflow → internal testing → external testing with Yugan, Khalid and Pittu.
- Run the detector regression set on the release build; run every package test; accessibility pass; screenshots light
  and dark on 6.9" and 13".
- App Privacy answers, export compliance, review notes, support and privacy URLs.

**Exit gate:** external beta used on at least three range sessions without a blocking defect; submission accepted;
`v8.0.0` tagged on the accepted commit.
