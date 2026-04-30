# 2244 App Workings and Features Report

Generated: 2026-04-30

## Scope and Source of Truth

This report explains how the app currently works and what features are present in the repository. It is based on the live SwiftUI entry points, package sources, and existing docs. When older roadmap notes disagree with live code, the live code is treated as authoritative.

Primary sources reviewed:

- `2244/game2244/game2244App.swift`
- `Packages/GameUI/Sources/GameUI/RootGameView.swift`
- `Packages/GameUI/Sources/GameUI/Home/HomeView.swift`
- `Packages/GameUI/Sources/GameUI/HybridGameScreen.swift`
- `Packages/GameCore/Sources/GameCore/GameEngine.swift`
- `Packages/GameApp/Sources/GameApp/GameStore.swift`
- `Packages/GameApp/Sources/GameApp/GameProgress.swift`
- `Docs/MASTER_APP_MAP.md`
- `Docs/IMPLEMENTATION_NOTES.md`
- `Docs/COMPREHENSIVE_AUTO_SAVE.md`
- `Docs/IAP_CATALOG.md`
- `Docs/FIREBASE_INTEGRATION_GUIDE.md`

## Executive Summary

2244 is a SwiftUI puzzle game built around connecting adjacent matching tiles, merging them into higher-value tiles, and progressing through an extremely long tile journey that eventually reaches alpha-suffix values and infinity. The app is no longer just a basic board prototype: the current code includes a home hub, standard gameplay, daily rewards, daily quests, achievements, challenges, a custom challenge designer, leaderboards, player profiles, themes, music themes, a shop, in-app purchases, ads, Game Center, Firebase integration, reporting, and comprehensive auto-save.

The app is organized into local Swift packages:

- `GameCore`: board model, tile math, chain validation, merge engine, power-up mechanics, challenge models, services protocols, and domain models.
- `GameApp`: observable app state, progress persistence, journey systems, economy stores, challenge stores, shop state, wheel state, achievement evaluation, and environment wiring.
- `GameUI`: SwiftUI screens and reusable UI components.
- `GameServices`: Firebase, AdMob, StoreKit-adjacent service implementations, audio, remote config, reports, and leaderboard service implementations.
- `GameTestingSupport`: test fixtures and helpers.
- `GlassPreview`: visual preview/debug support for glass-styled board experiences.

## How the App Starts

The app boots from `game2244App`. On launch it creates long-lived state and service objects, injects them through SwiftUI environment values, sets up the background, and presents `RootGameView`.

Launch flow:

1. `game2244App` creates the main stores and services: `GameStore`, `HomeState`, `PurchaseService`, `LiveAdService`, `LiveAudioService`, `DefaultGameCenterService`, `AchievementStore`, `DailyClaimsStore`, `DailyQuestStore`, `ChallengeStore`, `ChallengeDesignerStore`, `SpinWheelState`, `SeasonHistoryStore`, and leaderboard/report clients.
2. It configures navigation appearance and selected themes from `AppStorage`.
3. It attaches the gem wallet to `GameStore` and `HomeState`.
4. It loads achievement and daily reward catalogs.
5. It wires achievement reward delivery so achievements and quests can grant gems, power-ups, spins, and boost multipliers.
6. It restores local progress, initializes Firebase if configured, signs in anonymously for Firebase-backed features, and sets up Game Center.
7. It prepares ads if the player is not ad-free.
8. It shows the first-launch `HowToPlayView` tutorial in non-debug builds when needed.
9. `RootGameView` decides whether the player is on the home hub, standard gameplay, or custom challenge gameplay.

## Main Navigation Model

`RootGameView` is the top-level state machine. It switches between:

- `HomeView`: the main hub and default destination.
- `HybridGameScreen`: the standard endless game screen.
- `CustomChallengeGameScreen`: a sandboxed challenge game screen.

`HomeView` opens most feature areas as sheets or full-screen adaptive sheets:

- Daily rewards
- Free spin wheel
- Shop
- Music themes
- Boosts
- Challenge mode
- Challenge designer
- Weekly/best offer
- Theme picker
- Profile
- Achievements
- Leaderboard
- Settings

The detailed route inventory is maintained in `Docs/MASTER_APP_MAP.md`.

## Core Gameplay

The main game is a 5-column by 8-row tile board managed by `GameEngine` and exposed through `GameStore`. The normal configuration keeps the board full by applying gravity and refilling empty cells after merges and destructive actions.

Core rules:

- The player starts a chain with at least two adjacent tiles.
- The first two tiles must match.
- After the first pair, each next tile must either match the previous tile or be one step higher, meaning double the previous value.
- Adjacent movement includes diagonals.
- Locked tiles cannot merge.
- Infinity tiles can merge with other infinity tiles, and mixed chains can end in infinity under special rules.
- Reusing a tile in the same chain is invalid.

When a valid chain commits:

1. The engine validates adjacency and step progression.
2. The selected tiles are consumed.
3. A result tile is placed at the last chain position.
4. Score is awarded using step-based tile math and active score multipliers.
5. Moves increment.
6. Long chains of 10 or more tiles grant bonus gems.
7. Highest tile and journey progress update.
8. Milestone unlock, added, and excluded notifications may be queued.
9. Gravity and refill run.
10. The engine checks whether any valid moves remain.

The engine also supports:

- deterministic seeded random generation;
- score values larger than regular integers via `AlphaNumber`;
- alpha/abbreviation tile labels;
- infinity merge counting for a Hall of Fame leaderboard;
- milestone-based tile elimination and cleanup;
- gift cells and gift rewards;
- undo state;
- replay export/import support through `GameStore`.

## Standard Game Screen

`HybridGameScreen` is the live standard gameplay screen. It renders:

- the score and top HUD;
- milestone progress;
- the main glass-styled board;
- compact or regular power-up docks depending on size class;
- banner ads for non-ad-free players;
- wallpaper background;
- pause, shop, leaderboard, gift, unlock, notification, and game-over overlays.

Important gameplay UX behaviors:

- The app auto-saves on every move, score change, gem change, and background transition.
- Low valid-move counts trigger a "Low On Moves" prompt.
- Out-of-moves states show recovery choices before final game over.
- The game can restart from milestone tiers after game over.
- The first infinity creation plays celebration audio.
- Pending unlock rewards can be multiplied through a spinner-style reward sheet.

## Power-Ups and Boosts

The game includes several direct board power-ups:

- Hammer: removes a selected tile, then gravity/refill resolves the board.
- Swap: swaps two selected tiles without gravity.
- Magnet/MegaMerge: pulls all matching-value tiles into a target merge.
- Undo: restores the previous state when available.
- Shuffle: exists in the engine and inventory model, though the primary docks emphasize hammer, swap, magnet, and undo.
- Double: doubles a target tile through special prompt/reward logic.

Power-up availability comes from inventory first, then gem pricing. Prices scale with progression and can be reduced by power-up discount boosts.

The separate `BoostsSheet` sells timed boosts using gems:

- Score boosts: 5x and 20x score boosts.
- Power-up discounts: 25 percent off and 50 percent off power-ups.
- Achievement boosts: 2x, 3x, 5x, 8x, and 11x progress multipliers.

Boosts persist through `UserDefaults` and `GameProgress` where applicable, with countdowns and queued/active states.

## Journey, Milestones, and Tile Progression

The app has a long-term tile journey visible from the home screen through `JourneyPanel`. It tracks the highest tile ever reached and uses milestone planners to show current, previous, and upcoming milestones.

Journey-related behavior includes:

- home hub progress display;
- rank and milestone display;
- tile unlock notifications;
- journey rewards for reaching new milestones;
- abbreviation-tier rewards and claims;
- tile color and label systems that continue past normal integer-size values;
- infinity tile support.

The engine also uses milestone progress to change gameplay over time. At certain milestones, lower-value tiles are excluded or removed so late-game boards stay relevant instead of being filled with obsolete low tiles.

## Daily Rewards, Streaks, and Quests

The daily system is split into three related surfaces:

- `DailyClaimsView`
- `DailyStreaksView`
- `DailyQuestsView` and the Daily Quests tab in `AchievementsView`

Daily claims:

- load rewards from bundled daily catalogs;
- show a timeline of claimable days;
- support catch-up claims;
- show the next claim timer;
- grant gems, hammers, magnets, swaps, spins, and multipliers through the shared reward handler;
- disable rewards while the player is banned.

Daily streaks:

- show the current streak;
- show progress toward streak milestones;
- display 365-day milestone rewards;
- provide milestone detail sheets.

Daily quests:

- reset daily;
- show progress bars and reward summaries;
- include tile-reach quests and other daily goals;
- grant rewards through `DailyQuestStore`.

## Achievements

Achievements are loaded from the bundled `2244_achievements` catalog into `AchievementStore`. `AchievementEvaluator` listens to gameplay and other app events, updates cumulative counters, evaluates achievements, and makes rewards claimable.

Tracked achievement areas include:

- tile progression;
- total moves;
- chain combo sizes;
- total merged tiles;
- hammer, swap, magnet, spin, and boost usage;
- game survival and game-over related progress;
- challenge creation/completion;
- infinity progression;
- playtime;
- daily claims;
- wheel reward collection;
- leaderboard rank.

The achievements screen supports:

- sorted claimable/in-progress/claimed rows;
- progress bars;
- tier views;
- claim buttons;
- claim all when multiple rewards are ready;
- a Daily Quests tab.

Achievement rewards can grant gems, power-ups, spins, and multipliers.

## Spin Wheel

`SpinWheelView` provides a timed and bonus-spin reward wheel.

Spin availability:

- A scheduled spin slot opens every 4 hours.
- The day has six slots: 12a, 4a, 8a, 12p, 4p, and 8p.
- Bonus spins are consumed before scheduled slot spins.
- The first install seeds one bonus spin.
- Banned players cannot spin.

Wheel rewards include:

- gift box;
- gems;
- hammers;
- swaps;
- magnets/MegaMerges;
- free spins;
- 2x, 3x, and 4x multipliers with timed durations.

The wheel has weighted geometry: the gift box has double weight compared with standard segments. The wheel also has tick sounds, haptic-style peg physics, and an active multiplier display.

## Challenges and Custom Challenge Designer

Challenge mode and custom challenges are separate from the standard endless run.

Challenge mode:

- `ChallengeStore` generates milestone challenges from 1M through 1B, alpha tiers, and infinity.
- Challenges unlock sequentially.
- The first challenge is available immediately.
- Each later challenge requires the previous challenge to be completed and then waits for a one-hour unlock delay.
- Completed challenges can be replayed.
- Challenge cards show target tiles, difficulty, status, and rewards.

Challenge gameplay:

- `CustomChallengeGameScreen` uses a sandboxed `GameStore`.
- Challenge play does not overwrite the normal board.
- The player's gem balance is still debited when challenge recovery/power-up spending occurs.
- Challenge completion can count toward achievements and daily quests.
- Premade challenge rewards are granted through `ChallengeStore`.
- Win conditions can target score, tile value, tile step, or chain length.
- A timer controls challenge duration.
- Out-of-moves and low-on-moves recovery prompts are available.

Challenge designer:

- `ChallengeDesignerView` lets the player choose a target milestone from 1M through infinity.
- Players adjust time, minimum tile, and level count.
- Candidate tile steps are generated automatically.
- The designer estimates reward gems from target difficulty, time, minimum tile, and levels.
- Generated configs launch into the same sandboxed challenge screen.

The Create feature unlocks at 1M. Challenge mode unlocks at 1B.

## Leaderboards, Hall of Fame, and Reporting

Leaderboard behavior is implemented through `LeaderboardView`, `LeaderboardModel`, and `LeaderboardClient`.

Supported leaderboard concepts:

- global leaderboard;
- country-aware filters;
- Hall of Fame/infinity count leaderboard;
- top 150 view;
- milestone-based rank context;
- player history view;
- score submission after gameplay;
- rank tracking for achievements.

Backend paths:

- Game Center is used as an iOS-native leaderboard backend.
- Firebase can be used for cross-platform leaderboard data when configured.
- App launch can mirror submissions to Firebase and Game Center.
- If Firebase is missing or not configured, the app falls back to Game Center where possible.

Reporting and moderation:

- Players can report other players from leaderboard/settings flows.
- Reports can be submitted to Firestore through `FirestoreReportService`.
- Local UX simulates investigation results and warns or bans the reporting user for false/abusive reports.
- The Firestore report service includes notes that server-side rules and Cloud Functions are still required for production moderation enforcement.

Ban state affects the app broadly. Banned users are blocked from gameplay entry points such as play, daily rewards, challenges, boosts, spins, and some reward flows. Ban durations use exact timestamps and escalate by offense count.

## Player Profile and Social Identity

`PlayerProfileView` shows the player's public-facing identity and stats.

Profile features include:

- player name;
- avatar customization;
- friend code;
- country selection;
- best score;
- best milestone;
- global rank;
- season card and season history;
- tier mastery grid;
- profile sharing;
- comparison with selected players.

Profile data is loaded through a `ProfileClient`, with local/mock-friendly defaults when needed. Avatar assets are bundled in the app asset catalog.

## Shop, In-App Purchases, Offers, and Ads

The shop uses `ShopView` and `ShopStore`. It loads `2244_shop_catalog.json` when available and falls back to a default catalog. Purchases are processed through `PurchaseService`, which uses StoreKit 2 verified transactions on iOS.

Shop tabs:

- Bundles
- Gems
- Perks

Canonical IAP products include:

- Remove Ads
- small, medium, and large coin/gem bundles;
- Power-Up Pack;
- premium music themes;
- Starter Pack;
- Mega Bundle;
- Auto-Claim Boosts monthly subscription;
- Pro monthly subscription;
- Pro yearly subscription.

Verified purchases can grant:

- gems;
- power-ups;
- ad-free entitlement;
- permanent theme ownership;
- subscription entitlements.

Weekly offers:

- rotate on a five-week cycle;
- can include ad removal, gems, hammers, swaps, magnets, spins, and boosts;
- show countdowns to the current Saturday deadline;
- auto-present once per ISO week.

Ads:

- `LiveAdService` is the active ad service.
- It supports banner, interstitial, rewarded, and rewarded interstitial placements.
- It uses Google Mobile Ads when available.
- It prepares consent through UMP before ad requests.
- It suppresses ads when ad-free or Pro entitlements are active.
- The home Bonus Chest flow uses a rewarded interstitial intro sheet.
- Rewarded ads only grant rewards from the ad reward callback.

## Themes, Wallpapers, and Music

Visual customization:

- tile themes via `ThemeRegistry`;
- background themes via `BackgroundThemeRegistry`;
- gameplay wallpapers via `WallpaperThemeRegistry`;
- play button color selection;
- color blind mode in pause/settings paths.

Theme storage is mostly handled through `AppStorage`, while observable app state avoids putting `@AppStorage` inside `@Observable` models.

Music themes:

- Piano, xylophone, and guitar are free.
- Kalimba, muted nylon, and drum use premium theme purchase flows mapped to StoreKit product IDs.
- `LiveAudioService` uses AVFoundation, supports background music, tap/merge sound effects, instrument-specific tap sequences, crossfade behavior, and cached settings.
- Settings allow music and sound effects volume/mute controls.

## Settings, Support, and Game Data

`SettingsView` covers:

- sound effect volume and mute;
- music volume and mute;
- haptics toggle;
- test sound/haptic action;
- reduce motion;
- hints;
- curved trail style;
- remove ads;
- restore purchases;
- Game Center status and dashboard;
- analytics toggle;
- ad privacy choices when required;
- how to play;
- tile info;
- perks info;
- valid moves info;
- contact support;
- report player;
- rate game;
- privacy policy and terms links;
- save slots;
- replay export;
- replay import;
- app version.

Save slots and replay sheets are available from settings. The main autosave system is separate and runs continuously during play.

## Persistence and Sync

The app has multiple persistence layers:

- `UserDefaults` for lightweight settings, flags, inventory, and local state.
- `UserDefaultsProgressStore` for structured `GameProgress`.
- `ProgressSyncCoordinator` to merge local and optional remote progress.
- `FirestoreProgressStore` when Firebase is configured.
- `GemWallet` for local/cloud gem balance sync.
- StoreKit current entitlements for purchase restoration and subscription reconciliation.

`GameProgress` stores:

- highest tile and highest tile step;
- best score, including large `AlphaNumber` support;
- gems;
- games played;
- achievements;
- theme;
- total merges and time played;
- unlocked themes;
- daily challenge counts and streaks;
- current session state;
- power-up inventory;
- tier mastery counts;
- journey state;
- session analytics;
- infinity achievement and infinity merge count;
- active and queued score/power discount states.

The merge policy favors preserving progress: max highest tile, max score, max gems, union achievements, union unlocked themes, and merged inventory counts.

## Architecture Data Flow

Typical standard gameplay data flow:

1. The player interacts with a tile in `HybridGameScreen`.
2. UI calls `GameStore` path or power-up methods.
3. `GameStore` delegates validation and board mutation to `GameEngine`.
4. `GameEngine` returns a new `GameState`.
5. `GameStore` updates derived UI state, queues animations/notifications, evaluates achievements, processes rewards, and saves progress.
6. SwiftUI updates through environment-injected observable state.
7. On app backgrounding, move completion, or gem changes, progress is saved again.
8. On game end, leaderboard submission can run through the active leaderboard client.

## Accessibility and Platform Notes

The UI uses SwiftUI controls, system navigation, accessibility labels in several board and profile areas, reduce motion settings, haptic toggles, and scalable font helpers. The app includes iOS 26 Liquid Glass compatibility paths such as `.glassEffect` behind availability checks, while fallback material styles support older runtime paths in code.

## External Dependencies and Production Readiness Notes

Some features require external setup to work fully in production:

- Firebase requires `GoogleService-Info.plist`, anonymous auth, Firestore, and Cloud Functions/security rules for server-authoritative leaderboard and reporting behavior.
- StoreKit products must exist in App Store Connect with the exact IDs listed in `Docs/IAP_CATALOG.md`.
- AdMob requires production app/ad units, payment profile, privacy messaging, consent configuration, and App Store linkage.
- Report moderation has local UX and Firestore writes, but server-side de-dupe and ban escalation are expected to be enforced by backend functions.
- Older README roadmap sections are partly stale compared with the current implementation. `Docs/MASTER_APP_MAP.md` and the live Swift files are more reliable for current behavior.

## Feature Inventory

Current feature set by area:

| Area | Features |
| --- | --- |
| Core gameplay | 5x8 board, drag chains, diagonal adjacency, same/double chain rule, score, moves, gravity, refill, game over, replay export/import |
| Progression | highest tile, milestone road, unlock rewards, alpha labels, infinity, milestone tile cleanup, journey reward claims |
| Power-ups | hammer, swap, magnet/MegaMerge, undo, shuffle engine support, double prompt, gem pricing, inventory |
| Boosts | 5x and 20x score boosts, power-up discounts, achievement multipliers |
| Rewards | long-chain gems, gift boxes, unlock reward spinner, daily rewards, streak rewards, quest rewards, achievement rewards, spin wheel rewards |
| Daily systems | daily claims, catch-up claims, streaks, 365-day milestones, daily quests, reset countdown |
| Challenges | sequential milestone challenges, one-hour unlock delay, replay completed challenges, sandboxed challenge game, custom challenge designer |
| Social/profile | player name, avatar, country, friend code, profile share, comparison, season history, tier mastery |
| Leaderboards | global, country-aware filters, Hall of Fame/infinity count, top 150, rank context, player history, Game Center/Firebase clients |
| Moderation | report player sheet, Firestore report submission, warning/ban local UX, false-report abuse handling |
| Economy | gems, power-up purchases, shop catalog, bundles, perks, weekly offers, StoreKit verified purchases, subscriptions |
| Ads | banner, interstitial, rewarded, rewarded interstitial, consent preparation, ad-free suppression |
| Customization | tile themes, background themes, wallpapers, play button colors, music themes, color blind mode |
| Settings/support | audio, haptics, motion, hints, analytics, privacy choices, Game Center, support links, save slots, replay import/export |

## Bottom Line

2244 is currently a feature-rich tile-merge puzzle app with a modular SwiftUI architecture. The core loop is simple for the player: connect valid chains, merge upward, earn rewards, and chase higher milestones. Around that loop, the app layers long-term progression, economy, competitive leaderboards, daily engagement, customizable visuals/audio, and challenge modes. The largest production dependencies are external service configuration for Firebase, StoreKit, AdMob, and backend moderation.
