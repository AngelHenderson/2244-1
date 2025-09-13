2244 Game — Project Constitution (Spec Kit)

Last updated: 2025-09-12

Purpose

Establish durable engineering standards for the 2244 SwiftUI game so features ship fast without regressions. This constitution is a binding reference for /specify, /plan, /tasks, code review, and release.

⸻

Product North Star
    •    Feel: crisp, tactile, minimal UI with delightful feedback.
    •    Play: deterministic, fair, and fast. No dropped frames.
    •    Scale: feature flags and themes without re-architecture.
    •    Platforms: iOS 18+ (priority), iPadOS, macOS (Mac Catalyst) optional.

⸻

Target Stack
    •    Language: Swift 6 (strict concurrency, data‑race safety).
    •    UI: SwiftUI 5+ with Observation (@Observable / @Bindable).
    •    Architecture: value‑type game engine + thin SwiftUI shell.
    •    Persistence: UserDefaults for lightweight state; file‑based JSON for larger saves; Cloud sync optional.
    •    Game Services: Game Center (leaderboards/achievements).
    •    Monetization: StoreKit 2.
    •    Haptics: Core Haptics.
    •    Analytics: privacy‑preserving counters/events only.

⸻

Non‑Negotiable Principles
    1.    UI = Pure SwiftUI. No UIKit unless explicitly approved.
    2.    Observation over ObservableObject. Use @Observable models and @Bindable in Views. Don’t use @StateObject/ObservableObject except for 3rd‑party wrappers.
    3.    Strict Concurrency. Opt into Swift 6 language mode for app and packages. Actor‑isolate mutable state; annotate Sendable. Treat warnings as errors.
    4.    Single Source of Truth. The game engine owns score, board, RNG seed, move legality.
    5.    Determinism. All random behavior is seeded and injectable for tests and Daily modes.
    6.    Performance First. 60 fps target on low‑end devices. No synchronous disk or network on main actor.
    7.    Accessibility & Localization. Dynamic Type, VoiceOver labels, reduced motion.
    8.    Privacy by Design. No PII; opt‑in analytics; respectful defaults.

⸻

Module Boundaries
    •    GameEngine (pure): tile graph, merge rules, scoring, RNG, serializers.
    •    GameServices: Game Center, StoreKit 2, review prompts.
    •    AppUI: views, theming, navigation, haptics, settings.
    •    Persistence: settings, saves, migrations.
    •    Support: logging, diagnostics, feature flags.

Each module exposes stable, documented APIs. UI depends on Engine; never the reverse.

⸻

Concurrency & Isolation
    •    Mark view‑facing types @MainActor. Keep heavy work off the main actor.
    •    Use actor GameSessionActor for long‑lived mutable session state if needed.
    •    Prefer Task { @MainActor in … } only for short UI bridges; long work uses detached or background tasks with cancellation.
    •    All async APIs are async throws and cancellation‑aware. No unstructured threads.

⸻

State & Observation Rules
    •    Use @Observable models for view models and settings. Views receive models via @Environment or factory, not as long parameter lists.
    •    Don’t put @AppStorage inside @Observable. Bridge UserDefaults via a tiny adapter (e.g., SettingsStore) that syncs to observable state.
    •    Use @Bindable to bind to fields. Avoid @EnvironmentObject except for app‑wide singletons (e.g., ThemeStore).

⸻

Navigation
    •    Single NavigationStack per top‑level flow.
    •    Use a Route enum + optional NavigationPath for deep links and testing.
    •    All routes are testable via pure constructors (no side effects in body).

⸻

Game Loop & Rendering
    •    No per‑frame imperative loop. Use SwiftUI animations, TimelineView only when scheduled ticks are needed (e.g., countdowns).
    •    Animations must be interruptible and respect Reduce Motion. Avoid recursive withAnimation cascades.

⸻

Persistence & Saves
    •    Settings: SettingsStore bridges UserDefaults ⇄ observable state. Key names are centralized.
    •    Saves: Codable structs written atomically to app container. Migrations defined per version.
    •    Seeds: Persist RNG seed per game for replayability and fair challenges.

⸻

Game Center
    •    Optional sign‑in. Graceful degradation when unavailable.
    •    Leaderboards: one per mode; stable IDs; score composite documented in code and SPEC:leaderboards.md.
    •    Achievements: few, meaningful, progressive. All are triggerable from pure engine events.

⸻

StoreKit 2
    •    Use StoreKit 2 async APIs; no legacy receipts.
    •    Products/load cached into a simple store; purchases are idempotent and tested in UI tests.
    •    Entitlements mirrored in a tiny Entitlement value type; features are guarded centrally.

⸻

Haptics & Sound
    •    Haptics routes through a single Haptics service with fallbacks; disabled under Low Power/Reduce Motion.
    •    UI sounds are short and optional; respect Silent mode.

⸻

Error Handling & Logging
    •    Use os.Logger categories per module. No print in production.
    •    User‑visible errors are friendly and recoverable; technical details go to logs.

⸻

Theming & UI
    •    Color, typography, and spacing are centralized in Theme.
    •    Supports light/dark; high‑contrast palettes provided.
    •    All assets are vector or 3x and optimized.

⸻

Testing Strategy
    •    Engine: 95%+ coverage; property‑based tests for merges; seed‑based determinism.
    •    Snapshot: board/tile visuals across themes and Dynamic Type sizes.
    •    UI tests: new game, move sequence, purchase flow, GC sign‑in fallback.
    •    Performance tests: merge burst, theme switch, start‑game time.
    •    Use Xcode Test Plans for configurations (debug/release‑like, flags).

⸻

CI/CD
    •    Build + test on push; run lints and formatters.
    •    On main: sign, archive, and push TestFlight (manual promote to prod).
    •    Crash and performance telemetry via Xcode/Organizer.

⸻

Code Style & Reviews
    •    SwiftFormat + SwiftLint (warning‑free, treat warnings as errors on CI).
    •    PR checklist (see below) must pass before merge.
    •    No force‑unwraps in production code.

⸻

Security & Privacy
    •    No third‑party trackers. Only first‑party, aggregated analytics.
    •    Respect system privacy toggles; never fingerprint.

⸻

Spec Kit Alignment
    •    /specify produces one spec per feature; each links to its owning module.
    •    /plan is release‑scoped; references specs and risks.
    •    /tasks are granular (<1 day). Each task includes test notes.
    •    This constitution is the source of truth when conflicts arise.

⸻

Exceptions & Amendments
    •    Any deviation requires a short ADR (architecture decision record) linked in the PR and an update to this constitution if it becomes precedent.

⸻

PR Checklist (copy into template)
    •    Follows Observation (@Observable/@Bindable); no ObservableObject unless justified.
    •    No blocking work on @MainActor except UI composition.
    •    GameEngine changes are pure and covered by tests.
    •    Seeds persisted where randomness is used.
    •    Navigation routes added & tested.
    •    Accessibility labels & Dynamic Type verified.
    •    Haptics respect system settings; fallbacks present.
    •    StoreKit 2 happy‑path + cancel tested; idempotent restores.
    •    Game Center paths degrade gracefully when unavailable.
    •    Test Plan updated; performance baseline checked.
    •    No new force‑unwraps or prints; logs via os.Logger.

⸻

Minimal Interfaces (sketches)

// Settings bridge (no @AppStorage inside @Observable)
@Observable
final class SettingsStore {
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var colorScheme: ThemeID = .classic

    init(load: () -> Data? = UserDefaults.standard.data(forKey:),
         save: (Data) -> Void = { UserDefaults.standard.set($0, forKey: "settings") }) {
        if let data = load("settings"),
           let s = try? JSONDecoder().decode(Self.self, from: data) {
            self.soundEnabled = s.soundEnabled
            self.hapticsEnabled = s.hapticsEnabled
            self.colorScheme = s.colorScheme
        }
    }

    func persist(save: (Data) -> Void = { UserDefaults.standard.set($0, forKey: "settings") }) {
        if let data = try? JSONEncoder().encode(self) { save(data) }
    }
}

// Deterministic engine entry
struct GameEngine: Sendable, Codable {
    var board: Board
    var score: Int
    var rng: AnyRandomNumberGenerator

    mutating func apply(_ move: Move) -> MoveResult { /* pure */ }
}

// Single haptics facade
@MainActor
struct Haptics {
    static func tick() { /* Core Haptics or UIFeedbackGenerator fallback */ }
}


⸻

Owner
    •    Tech owner: Angel (Swift 6/SwiftUI)
    •    This document is authoritative. Keep it concise; update with each release.
