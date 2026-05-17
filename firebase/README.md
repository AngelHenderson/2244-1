# Firebase Configuration

This directory contains Firebase configuration files and setup instructions.

## Setup Instructions

1. **Use the Puzzle Games Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Open the existing project named "Puzzle Games" (`project-7513530591038917977`)
   - Enable Authentication, Firestore, and Cloud Functions

2. **iOS App Configuration**
   - Add an iOS app to your Firebase project
   - Use bundle ID: `com.ideabloomlabs.game2244` (the app target's current release bundle identifier)
   - Download `GoogleService-Info.plist`
   - Keep the Firebase iOS API key restricted to bundle ID
     `com.ideabloomlabs.game2244` and the Firebase API target allowlist in
     Google Cloud APIs & Services → Credentials
   - Keep the actual configuration local and out of commits:
     ```bash
     cp ~/Downloads/GoogleService-Info.plist /Users/angelhenderson/Development/Personal/2244/2244/game2244/GoogleService-Info.plist
     ```

3. **Authentication Setup**
   - Enable Sign-in methods in Firebase Console:
     - Email/Password (for account creation and sign-in)
     - Anonymous (for guest users)
     - Apple Sign-In (optional, if account linking is added)
     - Google Sign-In (optional)
     - Phone (for phone verification, if you want SMS verification live)

4. **Firestore Database**
   - Firestore exists in Native mode in `nam5`
   - Deploy security rules and indexes from this directory:
     ```bash
     npm --prefix firebase run deploy:firestore
     ```

5. **Cloud Functions**
   - Deploy the existing functions:
     ```bash
     npm --prefix firebase run deploy:functions
     ```
   - Keep old container images cleaned up:
     ```bash
     npm --prefix firebase run artifacts:setpolicy
     ```
   - If callable requests return an HTTP 401 before reaching function code,
     restore the gen2 invoker binding:
     ```bash
     npm --prefix firebase run functions:allow-invoker
     ```

## Local Firebase CLI

The Firebase CLI is installed as a local dev dependency in this directory.
Use npm scripts instead of relying on a global `firebase` binary:

```bash
npm --prefix firebase run firebase -- --version
npm --prefix firebase run projects
npm --prefix firebase run deploy:rules
npm --prefix firebase run deploy:indexes
npm --prefix firebase run deploy:firestore
npm --prefix firebase run deploy:functions
npm --prefix firebase run functions:allow-invoker
npm --prefix firebase run artifacts:setpolicy
```

`submitScore` is deployed as a callable second-generation Cloud Function in
`us-central1` on Node.js 22. It allows public Cloud Run invocation so Firebase
callable clients can reach the handler, then enforces Firebase Auth inside the
function before accepting score writes.

## Project Structure

```
firebase/
├── package.json                        # Local Firebase CLI scripts
├── GoogleService-Info-template.plist  # Template configuration
├── firestore.rules                    # Security rules
├── functions/                         # Cloud Functions
│   ├── src/
│   │   ├── index.ts                  # Main functions export
│   │   └── submitScore.ts            # Score submission function
│   ├── package.json                  # Dependencies
│   └── tsconfig.json                 # TypeScript config
└── firebase.json                     # Firebase project config
```

## Environment Variables

Set these in your Cloud Functions environment:

```bash
firebase functions:config:set app.name="Game 2244"
firebase functions:config:set app.version="1.0.0"
```

## Security Considerations

- All score submissions are server-authoritative
- Client apps cannot write directly to Firestore
- The live iOS Firebase API key is restricted to
  `com.ideabloomlabs.game2244` plus Firebase API targets
- Consider implementing App Attest (iOS) for additional security
- Rate limiting is built into Cloud Functions

## Cost Estimation

For a typical puzzle game:
- **Firestore**: ~$1-5/month (read/write operations)
- **Cloud Functions**: ~$0.40/month (invocations)
- **Authentication**: Free for <50k MAU
- **Total**: <$10/month for moderate usage

## Testing

Use the Firebase Emulator Suite for local development:

```bash
firebase emulators:start --only firestore,functions,auth
```

Configure your iOS app to use emulators in debug mode.

You can run the credential-free launch validation at any time:

```bash
node scripts/validate-launch-readiness.mjs
```

The script checks Firestore rules sync/coverage, StoreKit catalog consistency,
privacy manifest presence, release bundle settings, and that the real
`GoogleService-Info.plist` is ignored and untracked.
