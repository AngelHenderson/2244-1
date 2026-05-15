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
   - Keep the actual configuration local and out of commits:
     ```bash
     cp ~/Downloads/GoogleService-Info.plist /Users/angelhenderson/Development/Personal/2244/2244/game2244/GoogleService-Info.plist
     ```

3. **Authentication Setup**
   - Enable Sign-in methods in Firebase Console:
     - Email/Password (for account creation and sign-in)
     - Anonymous (for guest users)
     - Apple Sign-In (for iOS users)
     - Google Sign-In (optional)
     - Phone (for phone verification, if you want SMS verification live)

4. **Firestore Database**
   - Create Firestore database in production mode
   - Deploy security rules (see `firestore.rules`)

5. **Cloud Functions**
   - Initialize Functions in your project:
     ```bash
     cd firebase
     firebase init functions
     ```
   - Deploy the functions (see `functions/` directory)

## Project Structure

```
firebase/
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
