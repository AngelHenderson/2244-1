# 2244 iOS — Completeness Audit

**Audit date:** 2026-04-21
**Status:** Historical snapshot. Several findings in this report have since
been addressed or superseded by the live code and `Docs/MASTER_APP_MAP.md`,
including deep-link registration, StoreKit product IDs, pause routing,
daily-streak routing, Firebase/Game Center leaderboard wiring, Firestore
report submission, Firebase Analytics injection, local reminder scheduling,
and Firestore-backed social services.
**Auditor:** Senior staff review (read-only)
**Target under audit:** `game2244` scheme, workspace `game2244.xcworkspace`, source tree `/2244/game2244/`
**Build result:** `xcodebuild ... iphonesimulator ... clean build` → exit 0, 2 warnings (both `GKGameCenterViewController` deprecated on iOS 26 — SettingsView.swift:425, SettingsView.swift:478)

---

## 0. Doc source reconciliation

The request named three source docs. Only one exists as stated:

| Requested | Found | Notes |
| --- | --- | --- |
| `MasterGodPlanReport.md` | `Docs/MASTER_APP_MAP.md` (commit 9b709b7) | Clear intent match — this is the baseline inventory. |
| `Architecture.md` | none | Used `README.md` §Architecture + `AGENTS.md` as proxy. |
| `FeatureList.md` | none | Used `specs/003-create-2244-initial/spec.md` (FR-001..FR-072) as functional baseline. |

Doc/code conflicts called out inline throughout. **The live code wins where it disagrees with docs**, per the Master App Map's own declaration (MASTER_APP_MAP.md:3).

Additional doc baseline mismatch (affecting how to interpret warnings):

- Project `CLAUDE.md` → iOS **18+**, Swift 6.
- Global `~/.claude/CLAUDE.md` → iOS **26**, Swift 6.2.
- `Package.swift` files and Xcode settings are the ground truth — not inspected here. The two `GKGameCenterViewController` deprecation warnings are relevant only under the iOS 26 baseline.

---

## 1. Executive summary

**Verdict: this app is mixed real and shell.** Offline single-player progression, gameplay, audio, challenges, daily loops and achievements are production-wired. Anything that requires a backend or a paywall is stubbed, misconfigured, or mocked well enough to *look* real.

| Bucket | Estimate | Confidence |
| --- | --- | --- |
| 🟢 Complete | ~55% | High |
| 🟡 Partial  | ~25% | High |
| 🟠 Shell / Placeholder | ~15% | High |
| 🔴 Missing in active target | ~5%  | Medium |

Basis: ~45 screen/system surfaces enumerated in the Master App Map + FR-001..FR-072. Percentages are weighted by user-visible impact, not file count.

**Biggest reasons the app is not fully complete:**

1. **Remove-ads IAP is wired to a typo'd product ID** — `com.game2248.adfree` in `Packages/GameCore/Sources/GameCore/Services/PurchaseService.swift:9`. Every other reference (README, CLAUDE.md, IAPProduct.swift catalog, IAPContractTests, specs) uses `com.game2244.adfree`. The production purchase will never find a matching StoreKit product. This is a ship-blocker, not polish.
2. **Leaderboard backend is disconnected.** `.environment(\.leaderboardClient, .noop)` is injected twice in `2244/game2244/game2244App.swift` (lines 105, 312). The `.noop` client is **not empty** — it generates 150+ realistic fake entries with country filters, hall-of-fame mode, dynamic player counts, and a resolved "me" entry (`LeaderboardClient.swift:4316–4402`). `submitScore: { _ in }` is a silent no-op. A real `.firebase(service:)` variant exists at `FirebaseLeaderboardClient.swift:15` but is never called in the live app. Rich mock data masquerades as a shipped feature.
3. **Premium paywall is absent.** Spec FR-028/FR-035 require IAP gating on premium music themes (Cyberpunk, Lofi, Orchestral) and premium tile themes. `IAPProduct.swift:120–142` defines the product IDs. `MusicThemesView` still shows `priceLabel: "$0.99"` decoratively but calls `audioService.setCurrentMusicTheme()` unconditionally (MusicThemesView.swift:149) — no entitlement check, no `onPurchase` wiring (HomeView hosts both closures as `print` stubs at HomeView.swift:285, 288). `ThemePickerView` has zero gating on any of the 20 tile themes.
4. **No real ad service.** `DummyAdService()` is the live-injected ad service (`game2244App.swift:48`). All ad methods sleep 0.5s and return success. FR-066/FR-038 (AdMob) is entirely absent.
5. **No cloud progress sync.** `ProgressSyncCoordinator(remote: nil, …)` at `RootGameView.swift:37–42`. Firebase initializes and anonymously signs in (game2244App.swift:126–128), and `GemWallet.startCloudSync()` pushes gem balance to Firestore, but GameState/achievements/challenges are UserDefaults-only.
6. **Report moderation is theater.** `ReportPlayerSheet` fills out a form, opens a `mailto:support@game2244.com`, and locally flips `Bool.random()` to decide validity (`SettingsView.swift:589–593`).

---

## 2. Screen-by-screen audit

Only **deltas** from the Master App Map's own per-screen status are shown, plus evidence. Screens marked `live` in the map and confirmed true are noted briefly.

### Root and hub surfaces

| Screen | Map | Found | Evidence | Delta |
| --- | --- | --- | --- | --- |
| `game2244App` | live | 🟢 | `2244/game2244/game2244App.swift:79–256` boots all stores, Firebase, GC, achievements, daily catalogs, reward dispatch closure. | Confirmed. |
| `RootGameView` | live | 🟡 | `Packages/GameUI/Sources/GameUI/RootGameView.swift:6–398`. State machine works; but `makeHomeActions()` contains eight `print`-only TODO handlers (lines 238–265). HomeView bypasses six of them via its own `@State` sheet toggles. **`openSaleOffer` (line 262) is still wired to the SALE OFFER rail button** (`HomeView.swift:109`) → dead tap. | Downgraded from live to 🟡. |
| `HomeView` | live | 🟢 | `HomeView.swift:47–346`. All 14 user-visible rail/dock entries either route via `isShowing*` sheet state or via `actions.*`. The only action that's still a no-op is `openSaleOffer`. | Confirmed with one exception above. |
| `HowToPlayView` | live | 🟡 | Tutorial itself is complete; **auto-presentation is gated behind `#if !DEBUG`** (`game2244App.swift:242–248`). Release builds show it once; Debug builds never do, so developers cannot verify the first-launch flow without toggling the flag. | Confirmed as written in map's §7, worth an explicit mark. |

### Gameplay / challenge / reward surfaces

| Screen | Map | Found | Evidence | Delta |
| --- | --- | --- | --- | --- |
| `HybridGameScreen` | live | 🟢 | `HybridGameScreen.swift`, 1689 lines. Autosave on move, gem change, and scenePhase transitions via `gameStore.saveProgressImmediately()` (≈ lines 335–361). Real power-up routing, game-over detection, and milestone alerts. One placeholder label (`// Use shuffle as placeholder for magnet` in analytics, line 821) is cosmetic. | Confirmed. |
| `PauseSheet` | live | 🟢 | `PauseSheet.swift:4–70`. Real state, `@AppStorage` for theme/background, real reset. | Confirmed. |
| `GiftRewardView` | live | 🟡 | Full UI (`GiftRewardView.swift`). Triggered by `gameStore.pendingGiftReward` binding — real. `isFromGlassShatter` flag present but glass-shatter gameplay trigger is in GameStore logic, not UI-visible. | Confirmed as live, flagged as partial only because the event source is opaque from the UI layer. |
| `RewardSpinnerView` | live | 🟠 | Mutually exclusive with `UnlockedNotificationView` at `HybridGameScreen.swift:343–346`. Because `currentNotification != nil` is set on every milestone unlock, the spinner never wins. The notification view owns the claim path. | **Downgraded to 🟠** — surface exists, is reachable, but almost never displayed in practice. |
| Unlocked/Added/Excluded notifications | live | 🟢 | `MergeNotificationViews.swift`. All three branches present, claim flow calls `gameStore.claimPendingUnlockReward(multiplier:)`. | Confirmed. |
| `CustomChallengeGameScreen` | live | 🟢 | `CustomChallengeGameScreen.swift`, sandboxed `challengeGameStore` (line 11), gem spend syncs `homeState.gems` → `gameStore.coins` on dismiss (RootGameView.swift:66–67). One TODO ("Track chain lengths", ≈ line 979). | Confirmed. |
| `ChallengeModeView`, `IconLegendSheet` | live | 🟢 | `ChallengeModeView.swift`. Real `ChallengeStore` timeline, playability via `store.status()`. Pre-made challenges route through sandboxed `CustomChallengeConfig` launcher (RootGameView.swift:146–167). | Confirmed. |
| `ChallengeDesignerView` | live | 🟢 | `ChallengeDesignerView.swift`. Real `ChallengeDesignerStore` drive. | Confirmed. |

### Progression / daily / reward surfaces

| Screen | Map | Found | Evidence | Delta |
| --- | --- | --- | --- | --- |
| `DailyClaimsView` | live | 🟢 | Real `DailyClaimsStore` with procedural 365-day catalog, catch-up logic (`DailyClaimsStore.swift:107–189`), yearly unlock gating (lines 302–310). Bundled JSON at `2244/game2244/JSON/daily_streaks_365.json`. | Confirmed. |
| `DailyStreaksView` + `StreakDetailSheet` | live | 🟢 | `DailyStreaksView.swift`. Real unlock thresholds tied to `store.currentStreak`. | Confirmed. |
| `DailyQuestsView` | live | 🟡 | Quests defined (6), reset on calendar day (`DailyQuestStore.swift:254–281`), claim grants gems. **Claim path writes `coins` directly to UserDefaults and posts `GemsDidChange` notification** rather than routing through `GemWallet.deposit`. Dual-write bug risk — works today, fragile tomorrow. | **Downgrade live → 🟡** for architectural inconsistency. |
| `AchievementsView` + `AllTiersView` | live | 🟢 | Catalog loads from `2244/game2244/JSON/2244_achievements.json` at `game2244App.swift:156`. `AchievementEvaluator` wired at line 212 + `achievementStore.onReward` dispatches to gems/power-ups/spins/multipliers. Claim-all present. | Confirmed. |
| `SpinWheelView` | live | 🟢 | Real `WheelEngine` physics (velocity, drag, snap), deterministic outcome at segment snap. `SpinWheelState` 4-hour slot cadence + bonus spins + multiplier inventory all persisted. | Confirmed. |
| `BoostsSheet` | live | 🟢 | `BoostsSheet.swift`. Purchase calls `gameStore.purchaseScoreBoost/purchasePowerDiscount/purchaseAchievementBoost` which deduct gems and set expiry. Countdown text real. | Confirmed. |

### Shop / offer / customization surfaces

| Screen | Map | Found | Evidence | Delta |
| --- | --- | --- | --- | --- |
| `ShopView` | live | 🟡 | UI complete, tabs (Bundles/Gems/Perks) real, loads `2244_shop_catalog.json`. **But** `PurchaseService.adFreeProductID = "com.game2248.adfree"` (typo) — the ad-free purchase will never match a real StoreKit product. Gem-bundle product IDs in `IAPProduct.swift` (`com.game2244.coins.small/medium/large`) are **not wired** to `PurchaseService.ensureProductsLoaded` (which only loads the typo'd ad-free ID at line 46). So gem purchases in ShopStore grant gems via `GemWallet` without any StoreKit receipt flow. | **Downgrade live → 🟡** for the typo + the unwired gem SKUs. |
| `WeeklyOfferSheet` | live | 🟡 | 5-week rotation by date math with reference 2026-01-26 (`WeeklyOfferManager.swift:76–132`). **No "claimed this week" persistence**, no inventory depletion, no per-week lockout. Player can re-buy forever. Also rides the same typo'd StoreKit path as ShopView. | **Downgrade live → 🟡.** |
| `ThemePickerView` | live | 🟠 for paywall / 🟢 for selection | `ThemePickerView.swift:9–159`. All 20 tile themes, all backgrounds, all wallpapers, all 12 play-button colors freely selectable. **No premium gating anywhere** despite `IAPProduct.swift:120–142` defining `com.game2244.theme.cyberpunk/lofi/orchestral`. | **Split grade.** Selection flow is 🟢, monetization surface is 🟠. Reported as 🟡 overall. |
| `MusicThemesView` | partial | 🟠 | `MusicThemesView.swift:15–22`. Six instruments, all gated behind a decorative `priceLabel: "$0.99"` that is **never enforced**. Select button unconditionally calls `audioService.setCurrentMusicTheme()` (line 149). `onTry`/`onPurchase` closures are `print`-stubs from the HomeView host (HomeView.swift:283–290). No paywall, no entitlement check, no IAP wiring. Map called this "partial" because of host closures; the real gap is deeper. | **Confirm 🟠.** |

### Social / identity / moderation surfaces

| Screen | Map | Found | Evidence | Delta |
| --- | --- | --- | --- | --- |
| `LeaderboardView` | partial | 🟠 | `LeaderboardView.swift`, 1228 lines of rich UI rendering **100% mock data** via `.noop` client, which in turn calls `MockLeaderboardData` to generate 150+ entries with country filters, hall-of-fame ordering, dynamic player counts, duplicate-name resolution, and a "me" entry (`LeaderboardClient.swift:4316–4402`). `submitScore: { _ in }` is a real no-op. A real `FirebaseLeaderboardClient.firebase(service:)` exists but is never invoked in the live target (`2244/game2244/game2244App.swift:105` → `.noop`). | **Downgrade partial → 🟠.** This is the audit's largest case of "fake completeness." |
| `PlayerHistoryView` | partial | 🟠 | `PlayerHistoryView.swift`. `generateEvents()` synthesizes a 30-day event feed from `MockLeaderboardData.seededRandom()`. No backend, no persisted moderation feed. | Confirmed partial; I'd call it 🟠 — there's no real data path at all. |
| `PlayerProfileView` | live | 🟡 | Backed by `LiveProfileClient` → UserDefaults (`ProfileClient.swift:62+`). Rank computed from the same mock leaderboard data pool (`calculateGlobalRank`, line 227). Save/rename/country flows land in UserDefaults. No cloud profile, no real friend graph. | **Downgrade live → 🟡.** UI is real, backend isn't. |
| `RenameSheet` | live | 🟢 | Writes to UserDefaults via ProfileClient. | Confirmed. |
| `AvatarCustomizeView` | live | 🟢 | Static `AvatarCatalog`. | Confirmed. |
| `SeasonHistoryView` | partial | 🔴 | `ProfileSheets.swift:101–135`. Hardcoded `ForEach(1..<7)` with `["Bronze","Silver","Gold","Platinum","Diamond","Mythic"].randomElement()!`. Every re-render shuffles the labels. | **Downgrade partial → 🔴.** It's a decorative placeholder, not a feature. |
| `CompareView` | partial | 🟠 | `ProfileSheets.swift:139–439`. Search over `MockPlayer.generateAll()` mock dataset. No backend. | Confirmed partial; closer to 🟠. |
| `CountryPickerView` | live | 🟢 | Writes country to UserDefaults via `ProfileClient.updateCountry`. | Confirmed. |
| `SettingsView` | live | 🟢 | All settings sections real, audio/haptics toggles persisted, ad-free restore path present (though bound to the typo'd SKU). | Confirmed (with SKU caveat). |
| `GameCenterView` | partial | 🟡 | `SettingsView.swift:478–510`. Wraps deprecated `GKGameCenterViewController`. Builds with two iOS-26 deprecation warnings. Works, but on the clock. | Confirmed. |
| `ReportPlayerSheet` | partial | 🟠 | `SettingsView.swift:514–627`. Form → `mailto:`. Local "investigation" is `Bool.random()` (lines 589–593). Abuse tracking stored in `totalUniqueReports` `@AppStorage`. | **Downgrade partial → 🟠.** No real moderation path. |

### Reference and explainer surfaces (all 🟢)

`TilesInfoView`, `AbbreviationsListView`, `PerksInfoView`, `ValidMovesInfoView` — all real, local content, no backend expectation. Confirmed as Map says.

---

## 3. User flow audit

| Flow | Expected steps (Master Map §4) | Actual status | Status |
| --- | --- | --- | --- |
| First launch / onboarding | Boot → tutorial gate → Home | Works, but tutorial auto-present only in release builds (`#if !DEBUG` at game2244App.swift:242). Debug testers never see first-run UX unless they clear UserDefaults and flip the flag. | 🟡 |
| Regular play loop | Home → HybridGameScreen → pause/power-ups/shop/leaderboard/gifts/unlocks → Home | Full loop real. Autosave across scene phases. Power-ups real. Leaderboard reachable but populated with mock data; score submission is a no-op. | 🟡 (leaderboard leg) |
| Daily progression loop | Home → DailyClaims / DailyStreaks / DailyQuests / Achievements | Full loop real and persisted. | 🟢 |
| Challenge loop | Home → ChallengeMode or Designer → CustomChallengeGameScreen → return to correct parent | Full loop real, sandboxed GameStore, correct reopen logic on dismiss (RootGameView.swift:85–99). | 🟢 |
| Economy / customization loop | Home → Shop / WeeklyOffer / SpinWheel / Boosts / ThemePicker / MusicThemes | Reachable; but ad-free IAP typo'd, gem SKUs unwired, weekly offer re-buyable, premium themes ungated, music themes free for all. | 🟠 |
| Social / identity / moderation | Home → Profile / Achievements / Leaderboard / Settings → nested flows | Reachable and UI-complete. Leaderboard mocked, profile local, reports are `Bool.random()`. | 🟠 |

---

## 4. Missing / shell / placeholder inventory

**Clearly shells** (look done, aren't):
- `SeasonHistoryView` — randomized season labels on every redraw.
- `ReportPlayerSheet` — form + email + coin-flip evaluation.
- `PlayerHistoryView` — synthetic event feed.
- `CompareView` — mock player dataset.
- `LeaderboardView` in live target — mock dataset + no-op submit.
- `MusicThemesView` paywall — decorative `$0.99` label with no IAP.
- `WeeklyOfferSheet` — buyable every week with no lockout.
- `SALE OFFER` rail button on HomeView — routes to `actions.openSaleOffer` which prints "Open Sale Offer" and returns.

**Dead-end or nearly-dead wiring:**
- `RewardSpinnerView` — mutually-exclusive condition means `UnlockedNotificationView` always wins.
- `FirebaseLeaderboardClient.firebase(_:)` — real code, never injected.
- Six TODO `print` actions in `RootGameView.makeHomeActions` — bypassed by HomeView's own state, safe to delete, but they show architectural drift.

**Missing in active target** (expected by spec, not present):
- FR-038 / FR-066 — real AdMob banner + rewarded video ads. `DummyAdService` is the only impl.
- FR-029 — audio <500ms crossfade. `playMusic` uses hard-cut `stopMusic` before load; `setCurrentMusicTheme` only writes to storage (AudioService.swift:355–360).
- FR-043 — multiple save slots. `UserDefaultsStorageService` slot API exists, but only `"autosave"` is used (RootGameView.swift:319).
- FR-044 — replay export/import surface. **Backend exists** at `GameStore.swift:2709–2720` (`exportReplay`/`importReplay` returning `GR1|…base64`), but **no UI exposes it**. Share-code flow is missing.
- FR-045 — Firebase-extended features. Init and anonymous sign-in happen. Only `GemWallet.startCloudSync` actually writes to Firestore.
- FR-068 — player rank from a real global leaderboard. Rank comes from `UserLeaderboardData.globalRank(for:)` which queries the in-process `MockLeaderboardData` pool.
- Premium theme entitlement — `IAPProduct.swift` declares the three premium music + three premium tile SKUs, no enforcement.

---

## 5. Code quality / architecture notes

- **Stale sibling directory `/game2244/`.** Root-level `game2244/` contains only `Assets.xcassets` and an unreferenced `game2244.xcodeproj`. The workspace's sole project ref is `group:2244/game2244.xcodeproj` (contents.xcworkspacedata). The root `/game2244/` tree is dead — delete or document.
- **Legacy/alternate surfaces still compile.** Map §6 enumerates `HomeScreen`, `AllBlocksView`, `CreateChallengeSheet`, `GameView`, `StoreView`, `GlassGameView`. Not routed from `RootGameView`. `GlassPreview` is a separate package (`/Packages/GlassPreview`).
- **`FirebaseMocks.swift` correctly gated.** `#if !canImport(FirebaseAuth/...)`. Safe in production.
- **TODO/FIXME footprint:** 26 hits across 14 files. Heaviest: `RootGameView.swift` (8), `MonetizationService.swift` (2), `ProgressStore.swift` (2). Most are feature stubs, not bugs; the eight in RootGameView should be deleted since HomeView has fully replaced them.
- **Dual gem-write paths.** `DailyQuestStore.claim()` writes `coins` to UserDefaults and posts `GemsDidChange`, while the rest of the app goes through `GemWallet.deposit`. Same outcome today, but it's easy to get out of sync when cloud sync eventually attaches.
- **Wallet cloud sync is the only real Firestore write.** `GemWallet.startCloudSync()` writes `players/{playerId}/gems`. Everything else (GameState, challenges, achievements, progress) is local-only despite `ProgressSyncCoordinator` existing.
- **IAP declaration without wiring.** `IAPProduct.swift` declares 10 SKUs (coin packs, themes, starter pack, mega bundle, ad-free, powerup bundle). `PurchaseService.ensureProductsLoaded` loads only the typo'd ad-free. ShopStore grants products by direct `GemWallet.deposit` without receipt validation — a revenue-integrity hole.
- **`.noop` is a misleading name.** It implies empty behavior; it actually generates rich mock data for the leaderboard. Rename to `.mock` and make the true empty variant explicit, or the next dev will assume the leaderboard surface is honest.
- **Compiler warnings on iOS 26.** Both from the same `GKGameCenterViewController` reference (`SettingsView.swift:425, 478`). Migrate to the new APIs (GKAccessPoint + leaderboard-specific VCs) before the baseline tightens.
- **Replay serialization tag `GR1|...`** — solid format, no schema version growth plan. Future replay refactors will need a V2 tag path.

---

## 6. Ship readiness

**Could ship today (assuming offline single-player and paid-install monetization only):**
- Core gameplay, chains, merges, power-ups, autosave.
- Daily claims, streaks, quests, achievements with bundled catalogs.
- Challenge browsing + designer + sandboxed challenge runs.
- Spin wheel with multiplier inventory.
- Boosts storefront (gem-spend only).
- Profile rename / avatar / country (local-only).
- Tutorial on first launch.

**Would feel obviously unfinished to a user:**
- SALE OFFER rail button does nothing.
- Remove-ads purchase fails silently.
- Season history randomizes labels every render.
- RewardSpinnerView never appears (notifications always pre-empt).
- Music themes claim `$0.99` but give themselves away.

**Risky because it looks implemented:**
- Leaderboard: mocked so well that players and stakeholders will both think it works. Once real submissions go live, the fake history will stay cached in the mock source and create confusing "missing" players. Ship with `.firebase(...)` wired or disable the surface.
- Report a Player: a user who reports will genuinely believe they triggered moderation. There is none.
- Friend code / compare / country filters: all against mock dataset; any "friend" a user finds doesn't exist.
- Gem bundle purchases: grant coins without a StoreKit receipt. Revenue-integrity hole + App Review risk.

**Must complete before production release (non-negotiable):**
1. Fix the `com.game2248.adfree` typo and verify App Store Connect entitlement matches.
2. Route all declared IAP SKUs through `PurchaseService.ensureProductsLoaded` and enforce receipts before granting gems or themes.
3. Wire `.environment(\.leaderboardClient, .firebase(LeaderboardService()))` (or Game Center variant) and validate `submitScore`.
4. Replace `DummyAdService` or explicitly ship ad-free by default; do not ship an ad-supported build with Dummy.
5. Gate premium themes + premium music behind IAP entitlement.
6. Kill or wire the `SALE OFFER` tap path.

---

## 7. Actionable backlog

### Priority 0 — ship-blocking / misleading flows

- **Fix ad-free product ID typo.** `Packages/GameCore/Sources/GameCore/Services/PurchaseService.swift:9`. Change `com.game2248.adfree` → `com.game2244.adfree`. Verify `IAPContractTests` pass against the corrected ID.
- **Replace the leaderboard `.noop` injection with a real client** at `2244/game2244/game2244App.swift:105`. If Firebase: `LeaderboardClient.firebase(LeaderboardService())`. Add a visible empty/loading state for when the backend returns nothing — do not fall back to mock data.
- **Wire or disable the SALE OFFER button.** `HomeView.swift:109` + `RootGameView.swift:262`. Either implement or remove the rail item.
- **Wire all StoreKit product IDs.** Extend `PurchaseService.ensureProductsLoaded` to cover the 10 SKUs declared in `IAPProduct.swift`. Block gem/theme grants until the purchase is verified.

### Priority 1 — core missing functionality

- **Real ad service.** Replace `DummyAdService` with a concrete AdMob (or Apple Ads) implementation behind the existing protocol. Respect the ad-free entitlement.
- **Premium paywall.** Gate Cyberpunk/Lofi/Orchestral music themes (`Packages/GameUI/Sources/GameUI/Music/MusicThemesView.swift`) and premium tile themes (`ThemePickerView.swift`) behind the SKUs already defined in `IAPProduct.swift`. Show locked state + purchase CTA.
- **Remote progress sync.** Replace `remoteStore: nil` at `Packages/GameUI/Sources/GameUI/RootGameView.swift:38` with a `FirebaseProgressStore` (or CloudKit). Sync best score, highest tile, gems, achievements on game-end and app-background.
- **Report backend.** Replace the `Bool.random()` moderation logic at `Packages/GameUI/Sources/GameUI/Settings/SettingsView.swift:589` with a Firebase callable / REST submission. Keep the email fallback only if the backend is unreachable.

### Priority 2 — partial implementations blocking confidence

- **Music crossfade.** Implement <500ms crossfade in `Packages/GameServices/Sources/GameServices/AudioService.swift:setCurrentMusicTheme` using dual AVAudioPlayer volume ramps (FR-029).
- **Weekly offer purchase persistence.** Track "claimed offer" per-week in `WeeklyOfferManager` so users can't re-buy the same deal.
- **Season history real data.** Replace the randomized 6-season placeholder at `ProfileSheets.swift:101–135` with persisted season data from Firestore or a local season archive.
- **Dual gem-write cleanup.** Route `DailyQuestStore.claim` through `GemWallet.deposit` to match the rest of the app.
- **Delete stub TODO actions.** The eight `print` TODOs in `RootGameView.makeHomeActions` are superseded by HomeView state. Remove them to prevent future misuses.
- **iOS 26 Game Center migration.** Replace deprecated `GKGameCenterViewController` usage at `SettingsView.swift:425, 478` with `GKAccessPoint` + modern VC APIs.

### Priority 3 — polish and cleanup

- **Replay share UI.** Surface the existing `GameStore.exportReplay` / `importReplay` (GameStore.swift:2709) as a share-code flow (FR-044 UI).
- **Multi-slot save picker.** API exists in `UserDefaultsStorageService`. Add a UI surface to match FR-043.
- **Delete stale `/game2244/` root directory** after confirming it's not in any scheme.
- **Retire `RewardSpinnerView`** if `UnlockedNotificationView` is the intended unlock surface, or route non-milestone unlocks through the spinner.
- **Rename `LeaderboardClient.noop`** to `.mock` and add a true empty variant.
- **Remove or document** the alternate surfaces in Map §6 (`HomeScreen`, `AllBlocksView`, `CreateChallengeSheet`, `GameView`, `StoreView`, `GlassGameView`).
- **Add schema versioning to the `GR1|` replay tag** before the next replay format change.

---

## 8. Machine-readable summary

| Screen | Expected (Map) | Found | Evidence | Reachable |
| --- | --- | --- | --- | --- |
| game2244App | live | live | game2244App.swift:79 | yes |
| RootGameView | live | partial | RootGameView.swift:262 openSaleOffer TODO | yes |
| HomeView | live | live | HomeView.swift:47 | yes |
| HowToPlayView | live | partial | game2244App.swift:242 #if !DEBUG | yes (release only) |
| HybridGameScreen | live | live | HybridGameScreen.swift | yes |
| PauseSheet | live | live | PauseSheet.swift:4 | yes |
| GiftRewardView | live | partial | GiftRewardView.swift:114 | yes |
| RewardSpinnerView | live | shell | HybridGameScreen.swift:343 pre-empted | effectively no |
| Unlocked/Added/Excluded | live | live | MergeNotificationViews.swift | yes |
| CustomChallengeGameScreen | live | live | CustomChallengeGameScreen.swift | yes |
| ChallengeModeView | live | live | ChallengeModeView.swift | yes |
| IconLegendSheet | live | live | ChallengeModeView.swift | yes |
| ChallengeDesignerView | live | live | ChallengeDesignerView.swift | yes |
| DailyClaimsView | live | live | DailyClaimsStore.swift:416 | yes |
| IconLegendView | live | live | DailyClaimsView.swift:1329 | yes |
| DailyStreaksView | live | live | DailyStreaksView.swift | yes |
| StreakDetailSheet | live | live | DailyStreaksView.swift:315 | yes |
| DailyQuestsView | live | partial | DailyQuestStore.claim direct UD write | yes |
| AchievementsView | live | live | game2244App.swift:156 + AchievementsView.swift | yes |
| AllTiersView | live | live | AllTiersView.swift | yes |
| SpinWheelView | live | live | WheelEngine.swift | yes |
| BoostsSheet | live | live | BoostsSheet.swift:108 | yes |
| ShopView | live | partial | PurchaseService.swift:9 typo + unwired SKUs | yes |
| WeeklyOfferSheet | live | partial | WeeklyOfferManager.swift no-per-week-lockout | yes |
| ThemePickerView | live | partial | no premium gating | yes |
| MusicThemesView | partial | shell | MusicThemesView.swift:149 no paywall | yes |
| LeaderboardView | partial | shell | game2244App.swift:105 .noop + LeaderboardClient.swift:4316 mock | yes |
| PlayerHistoryView | partial | shell | PlayerHistoryView.swift generateEvents | yes |
| PlayerProfileView | live | partial | ProfileClient.swift:62 UserDefaults only | yes |
| RenameSheet | live | live | ProfileSheets.swift:6 | yes |
| AvatarCustomizeView | live | live | ProfileSheets.swift:46 | yes |
| SeasonHistoryView | partial | missing | ProfileSheets.swift:116 randomElement | yes |
| CompareView | partial | shell | ProfileSheets.swift:564 MockPlayer | yes |
| CountryPickerView | live | live | ProfileClient.updateCountry | yes |
| SettingsView | live | live | SettingsView.swift | yes |
| GameCenterView | partial | partial | SettingsView.swift:478 deprecated | yes |
| ReportPlayerSheet | partial | shell | SettingsView.swift:589 Bool.random | yes |
| TilesInfoView | live | live | TilesInfoView.swift | yes |
| AbbreviationsListView | live | live | TilesInfoView.swift | yes |
| PerksInfoView | live | live | PerksInfoView.swift | yes |
| ValidMovesInfoView | live | live | ValidMovesInfoView.swift | yes |
| SALE OFFER (HomeView rail) | live | shell | HomeView.swift:109 → RootGameView.swift:262 print | yes (dead tap) |
| LeaderboardClient backend | — | shell | FirebaseLeaderboardClient.swift:15 unused | no (not wired) |
| AdService | — | shell | DummyAdService in game2244App.swift:48 | yes (dummy) |
| ProgressSyncCoordinator remote | — | missing | RootGameView.swift:38 remoteStore:nil | n/a |
| Replay UI (FR-044) | — | missing | GameStore.swift:2709 backend only | no |
| Multi-slot saves (FR-043) | — | missing | RootGameView.swift:319 autosave only | no |
| Audio crossfade (FR-029) | — | missing | AudioService.swift:355 hard-cut | n/a |

---

## Final verdict

**This app is mixed real and shell.** The offline single-player experience — engine, progression, daily loops, challenges, achievements — is genuinely wired and production-grade. The *monetization, social, and moderation surfaces that make this a live service* are largely mock wrappers over UserDefaults. A player who never opens the leaderboard, never tries to buy ad-free, and never reports anyone would have a complete game. A player who does any of those three would find them either silently broken (IAP typo), silently dishonest (leaderboard mock), or silently inert (report random).

Ship a "no-IAP single-player" beta today. Fix P0 before any App Store submission that advertises leaderboards, monetization, or moderation.
