# HtooChoon — Flutter App

Cross-platform (Android / iOS / desktop) client for the HtooChoon learning
platform. This repository is a **read-only mirror of the Flutter app**, split out
from the private monorepo so builds run on free public GitHub Actions minutes.

- Source of truth: the private monorepo. Do not push app changes here directly —
  they are overwritten on the next sync.
- Backend, real-time services and admin tooling live in the private repo.
- CI: `.github/workflows/flutter.yaml`.

## Build
```bash
flutter pub get
flutter build apk        # Android
flutter build linux      # Linux desktop
```
