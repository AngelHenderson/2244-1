# Repository Guidelines

## Project Structure & Module Organization
Open `game2244.xcworkspace` for the full workspace. Runtime code lives in `game2244/` (app target) and the modular SwiftPM packages under `Packages/` (`GameCore`, `GameApp`, `GameUI`, `GameServices`, `GameTestingSupport`, `GlassPreview`). UI tests and integration flows sit in `game2244UITests/`, while Swift Testing specs for each module live in the matching `Packages/*/Tests` folders. Shared docs reside in `Docs/`, automation helpers in `scripts/`, and Firebase assets in `firebase/`.

## Build, Test, and Development Commands
Use Xcode or the CLI to build: `xcodebuild -workspace game2244.xcworkspace -scheme game2244 -destination 'platform=iOS Simulator,name=iPhone 16' build` for simulator runs, and add `-configuration Release -sdk iphoneos archive` for device-ready artifacts. Execute module tests with `swift test --package-path Packages/GameCore` (repeat for other packages) when iterating quickly. Run the end-to-end suite via `xcodebuild test -workspace game2244.xcworkspace -scheme game2244 -destination 'platform=iOS Simulator,name=iPhone 16'`. Invoke `scripts/create-new-feature.sh` to scaffold feature plans when collaborating with other agents.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines with four-space indentation, trailing commas in multi-line collections, and `final` where inheritance is not required. Types stay in UpperCamelCase (`GameEngine`), members in lowerCamelCase, and constants only use all caps for bridging C APIs. Keep public surface area inside the packages minimal; prefer internal extensions scoped to the relevant module. Place assets in `Assets.xcassets` and name them using dashed lower case (`tile-highlight`).

## Testing Guidelines
We rely on Swift's `Testing` framework—annotate entry points with `@Test` and use `#expect` assertions. Cover new engine or UI logic with deterministic seeds from `GameTestingSupport/TestHelpers.swift` so runs stay reproducible. Add snapshot or integration checks in `game2244UITests/` when UI surfaces change. Run `swift test --enable-code-coverage --package-path Packages/GameCore` before pushing; keep line coverage at or above the current baseline (≈80%) for touched targets.

## Commit & Pull Request Guidelines
Write imperative, sentence-case commit subjects (`Add merge animations`, `Refactor audio settings`) and keep related changes squashed. Each pull request should include a concise summary, affected modules, screenshots or screen recordings for UI updates, and links to tasks or issues. Document any configuration steps (e.g., Firebase keys) in the PR discussion and update `Docs/` when workflows change.

## Configuration Tips
Never commit `GoogleService-Info.plist`; store it locally under `firebase/` and add it to the Xcode target manually. Use simulator-specific destinations when running scripts to avoid overwriting production provisioning profiles, and refresh `firebase/README.md` if backend endpoints evolve.
