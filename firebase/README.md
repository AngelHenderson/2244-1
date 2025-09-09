# Firebase Configuration

This directory contains Firebase configuration files and setup instructions.

## Setup Instructions

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project named "game2244-firebase" (or your preferred name)
   - Enable Authentication, Firestore, and Cloud Functions

2. **iOS App Configuration**
   - Add an iOS app to your Firebase project
   - Use bundle ID: `com.game2244.app` (or match your actual bundle ID)
   - Download `GoogleService-Info.plist`
   - Replace the template file with the actual configuration:
     ```bash
     cp ~/Downloads/GoogleService-Info.plist /Users/angelhenderson/Developer/Personal/2244/game2244/GoogleService-Info.plist
     ```

3. **Authentication Setup**
   - Enable Sign-in methods in Firebase Console:
     - Anonymous (for guest users)
     - Apple Sign-In (for iOS users)
     - Google Sign-In (optional)

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