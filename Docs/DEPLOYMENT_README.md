# Deployment Notes

This guide is intentionally short. Older Firebase setup instructions were
removed because the app now has a single active backend deployment path.

## Source Of Truth

- App release checklist: `Docs/ReleaseReadiness.md`
- Firebase integration and smoke tests: `Docs/FIREBASE_INTEGRATION_GUIDE.md`
- Firebase CLI commands: `firebase/README.md`
- IAP catalog and sandbox checklist: `Docs/IAP_CATALOG.md`

## Firebase Deploy Path

Deploy only from the nested Firebase package:

```bash
npm --prefix firebase run deploy:firestore
npm --prefix firebase run deploy:functions
npm --prefix firebase run functions:allow-invoker
npm --prefix firebase run artifacts:setpolicy
```

The active Cloud Functions code lives under `firebase/functions/` and currently
exports:

- `submitScore` for server-authoritative leaderboard writes.
- `onReportCreated` for report de-dupe and moderation escalation.

There is no root-level `firebase.json` or root-level `functions/` deployment
path. If either reappears, `scripts/validate-launch-readiness.mjs` should fail.

## Local Gate

Run this before archiving or deploying:

```bash
node scripts/validate-launch-readiness.mjs
FIREBASE_SOURCE_FIRESTORE=1 xcodebuild -workspace game2244.xcworkspace \
  -scheme game2244 \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## Xcode Cloud

Set workflow environment variable `FIREBASE_SOURCE_FIRESTORE` to `1` in App
Store Connect for the Development Workflow. The committed app-project and
package lockfiles use Firebase's source-Firestore graph; without that Cloud
resolves `abseil-cpp-binary` / `grpc-binary` and reports the project
`Package.resolved` file as out of date when automatic dependency resolution is
disabled.

`ci_scripts/ci_pre_xcodebuild.sh` checks the variable before Xcode Cloud starts
the archive action and prints the exact fix if it is missing.
