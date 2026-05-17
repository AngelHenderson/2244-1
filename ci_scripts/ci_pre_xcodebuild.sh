#!/bin/zsh
set -euo pipefail

# FirebaseFirestore switches between binary and source dependencies during
# package resolution. Xcode Cloud archives disable automatic lockfile updates,
# so the workflow environment must match the committed source-Firestore
# Package.resolved files.
if [[ "${CI_XCODE_CLOUD:-}" == "TRUE" && "${FIREBASE_SOURCE_FIRESTORE:-}" != "1" ]]; then
  cat >&2 <<'EOF'
error: FIREBASE_SOURCE_FIRESTORE=1 is required for this Xcode Cloud workflow.

Set FIREBASE_SOURCE_FIRESTORE to 1 in App Store Connect:
Xcode Cloud > Workflows > Development Workflow > Environment.

Without this variable Firebase resolves abseil-cpp-binary/grpc-binary, which
makes 2244/game2244.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
look out of date when automatic dependency resolution is disabled.
EOF
  exit 1
fi

export FIREBASE_SOURCE_FIRESTORE=1
echo "FIREBASE_SOURCE_FIRESTORE=1"
