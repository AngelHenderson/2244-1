import SwiftUI
import GameApp
import GameCore

public struct OnboardingFlowView: View {
    @Environment(\.accountService) private var accountService
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var preferences = OnboardingPreferences()
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var accountStatus: String?
    @State private var showGuidebook = false

    private let onComplete: @MainActor (OnboardingPreferences) -> Void
    private let totalSteps = 8

    public init(onComplete: @escaping @MainActor (OnboardingPreferences) -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(.green)
                    .padding(.horizontal)
                    .padding(.top, 12)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    goalStep.tag(1)
                    dailyGoalStep.tag(2)
                    boardSetupStep.tag(3)
                    tutorialStep.tag(4)
                    accountStep.tag(5)
                    reminderStep.tag(6)
                    widgetStep.tag(7)
                }
                .platformPageTabViewStyle(indexDisplayMode: .never)

                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .buttonStyle(.bordered)
                    }

                    Button(step == totalSteps - 1 ? "Start playing" : "Continue") {
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Ultimate2244")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        preferences.completedAt = Date()
                        onComplete(preferences)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showGuidebook) {
                HowToPlayView()
            }
        }
        .trackScreen(.onboarding)
    }

    private var welcomeStep: some View {
        OnboardingStepLayout(
            icon: "sparkles",
            title: "Build bigger tiles every day",
            subtitle: "Ultimate2244 is a merge puzzle about planning chains, protecting open lanes, and chasing the next milestone."
        ) {
            Label("Endless runs, daily rewards, challenges, and leaderboards all unlock as you play.", systemImage: "square.grid.3x3.fill")
                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
        }
    }

    private var goalStep: some View {
        OnboardingStepLayout(icon: "target", title: "What are you here for?", subtitle: "This helps the app choose useful prompts.") {
            VStack(spacing: 10) {
                ForEach(PlayerGoal.allCases) { goal in
                    ChoiceRow(
                        title: goal.title,
                        systemImage: goal == preferences.goal ? "checkmark.circle.fill" : "circle",
                        isSelected: goal == preferences.goal
                    ) {
                        preferences.goal = goal
                    }
                }
            }
        }
    }

    private var dailyGoalStep: some View {
        OnboardingStepLayout(icon: "calendar.badge.clock", title: "Pick a daily play goal", subtitle: "You can change this later from reminders.") {
            VStack(spacing: 10) {
                ForEach([5, 10, 15, 20], id: \.self) { minutes in
                    ChoiceRow(
                        title: "\(minutes) min / day",
                        detail: minutes == 10 ? "Recommended" : nil,
                        systemImage: preferences.dailyPlayGoalMinutes == minutes ? "checkmark.circle.fill" : "circle",
                        isSelected: preferences.dailyPlayGoalMinutes == minutes
                    ) {
                        preferences.dailyPlayGoalMinutes = minutes
                    }
                }
            }
        }
    }

    private var boardSetupStep: some View {
        OnboardingStepLayout(icon: "paintpalette.fill", title: "Choose a board mood", subtitle: "This maps to Ultimate2244 backgrounds, not language courses.") {
            VStack(spacing: 10) {
                ForEach(["city_1", "jungle_1", "underwater_1", "desert_1"], id: \.self) { themeID in
                    ChoiceRow(
                        title: themeID.replacingOccurrences(of: "_", with: " ").capitalized,
                        systemImage: preferences.preferredBoardThemeID == themeID ? "checkmark.circle.fill" : "circle",
                        isSelected: preferences.preferredBoardThemeID == themeID
                    ) {
                        preferences.preferredBoardThemeID = themeID
                    }
                }
            }
        }
    }

    private var tutorialStep: some View {
        OnboardingStepLayout(icon: "book.closed.fill", title: "Learn the merge", subtitle: "Review the full guidebook or continue straight into the app.") {
            Button {
                showGuidebook = true
            } label: {
                Label("Open guidebook", systemImage: "book.pages.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var accountStep: some View {
        OnboardingStepLayout(icon: "person.crop.circle.badge.plus", title: "Protect your progress", subtitle: "Create or sign in to an account when Firebase Auth is configured. Local fallback keeps this screen usable offline.") {
            VStack(spacing: 10) {
                TextField("Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .platformTextInputAutocapitalizationWords()
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .platformTextInputAutocapitalizationNever()
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await createAccount() }
                } label: {
                    Label("Create account", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)
                if let accountStatus {
                    Text(accountStatus)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var reminderStep: some View {
        OnboardingStepLayout(icon: "bell.badge.fill", title: "Keep the streak alive", subtitle: "Ultimate2244 can send local reminders for streaks and quests.") {
            VStack(spacing: 10) {
                Toggle("Streak reminders", isOn: $preferences.wantsReminders)
                ChoiceRow(
                    title: "Daily target: \(preferences.dailyPlayGoalMinutes) minutes",
                    systemImage: "timer",
                    isSelected: true
                ) {}
            }
            .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
        }
    }

    private var widgetStep: some View {
        OnboardingStepLayout(icon: "rectangle.on.rectangle", title: "Add Ultimate2244 to your routine", subtitle: "Widget and lock-screen references become in-app CTAs for now.") {
            VStack(spacing: 10) {
                Toggle("Show widget and quick-start prompts", isOn: $preferences.hasSeenWidgetCTA)
                Text("The app will surface daily claim, streak, and challenge shortcuts inside Ultimate2244.")
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            preferences.completedAt = Date()
            onComplete(preferences)
            dismiss()
        }
    }

    private func createAccount() async {
        do {
            let profile = try await accountService.createAccount(email: email, password: password, displayName: displayName)
            preferences.wantsAccount = true
            accountStatus = "Signed in as \(profile.displayName)."
        } catch {
            accountStatus = error.localizedDescription
        }
    }
}

public struct PracticeHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameStore) private var gameStore
    @State private var moveStore = MoveReviewStore()
    @State private var selectedEntry: MoveReviewEntry?
    @State private var showGuidebook = false
    private let onPlayPractice: @MainActor (CustomChallengeConfig) -> Void
    private let onOpenDailyChallenge: @MainActor () -> Void
    private let onOpenCreate: @MainActor () -> Void
    private let onOpenProCoach: @MainActor () -> Void

    public init(
        onPlayPractice: @escaping @MainActor (CustomChallengeConfig) -> Void = { _ in },
        onOpenDailyChallenge: @escaping @MainActor () -> Void = {},
        onOpenCreate: @escaping @MainActor () -> Void = {},
        onOpenProCoach: @escaping @MainActor () -> Void = {}
    ) {
        self.onPlayPractice = onPlayPractice
        self.onOpenDailyChallenge = onOpenDailyChallenge
        self.onOpenCreate = onOpenCreate
        self.onOpenProCoach = onOpenProCoach
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        open(.todayReview)
                    } label: {
                        heroCard(
                            title: "Today's review",
                            subtitle: "Practice around your current highest tile: \(TileStepLabelFormatter.labelForStep(gameStore.state.highestTileStep)).",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(PracticeMode.allCases) { mode in
                            Button {
                                open(mode)
                            } label: {
                                ModeCard(title: mode.title, subtitle: mode.subtitle, systemImage: mode.systemImage)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Recent move reviews")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                    ForEach(moveStore.entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            ReviewEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Practice")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task {
                moveStore.seedIfEmpty(highestTileStep: gameStore.state.highestTileStep)
            }
            .sheet(item: $selectedEntry) { entry in
                MoveReviewDetailView(entry: entry)
            }
            .sheet(isPresented: $showGuidebook) {
                HowToPlayView()
            }
        }
        .trackScreen(.practice)
    }

    private func open(_ mode: PracticeMode) {
        switch mode {
        case .dailyChallenge:
            moveStore.record(MoveReviewEntry(
                boardSummary: mode.title,
                moveSummary: "Practice session started",
                explanation: "This daily objective focuses on merging your way to a target tile near your current milestone.",
                outcome: "Ready for a full run"
            ))
            let step = max(2, gameStore.state.highestTileStep)
            let config = CustomChallengeConfig(
                target: .tileStep(step),
                timeLimitSeconds: nil,
                minTileLevel: 0,
                levels: 7,
                tileAssignments: [:],
                predictedRewardGems: 50,
                isPractice: true
            )
            onPlayPractice(config)
        case .customChallenge:
            onOpenCreate()
        case .guidebook:
            showGuidebook = true
        case .proCoach:
            onOpenProCoach()
        case .todayReview:
            moveStore.record(MoveReviewEntry(
                boardSummary: mode.title,
                moveSummary: "Practice session started",
                explanation: "This drill uses deterministic 2244 rules to review board shape, chain length, and recovery options.",
                outcome: "Ready for a full run"
            ))
            let step = max(2, gameStore.state.highestTileStep)
            let config = CustomChallengeConfig(
                target: .tileStep(step),
                timeLimitSeconds: 300,
                minTileLevel: 0,
                levels: 7,
                tileAssignments: [:],
                predictedRewardGems: 50,
                isPractice: true
            )
            onPlayPractice(config)

        case .tileDrills:
            moveStore.record(MoveReviewEntry(
                boardSummary: mode.title,
                moveSummary: "Practice session started",
                explanation: "This drill uses deterministic 2244 rules to review board shape, chain length, and recovery options.",
                outcome: "Ready for a full run"
            ))
            let step = max(2, gameStore.state.highestTileStep + 1)
            let config = CustomChallengeConfig(
                target: .tileStep(step),
                timeLimitSeconds: 240,
                minTileLevel: 0,
                levels: 7,
                tileAssignments: [:],
                predictedRewardGems: 60,
                isPractice: true
            )
            onPlayPractice(config)
        case .rapidReview:
            moveStore.record(MoveReviewEntry(
                boardSummary: mode.title,
                moveSummary: "Practice session started",
                explanation: "This drill uses deterministic 2244 rules to review board shape, chain length, and recovery options.",
                outcome: "Ready for a full run"
            ))
            let config = CustomChallengeConfig(
                target: .score(10_000),
                timeLimitSeconds: 45,
                minTileLevel: 0,
                levels: 7,
                tileAssignments: [:],
                predictedRewardGems: 30,
                isPractice: true
            )
            onPlayPractice(config)
        case .timedSprint:
            moveStore.record(MoveReviewEntry(
                boardSummary: mode.title,
                moveSummary: "Practice session started",
                explanation: "This drill uses deterministic 2244 rules to review board shape, chain length, and recovery options.",
                outcome: "Ready for a full run"
            ))
            let step = max(3, gameStore.state.highestTileStep + 2)
            let config = CustomChallengeConfig(
                target: .tileStep(step),
                timeLimitSeconds: 60,
                minTileLevel: 0,
                levels: 7,
                tileAssignments: [:],
                predictedRewardGems: 75,
                isPractice: true
            )
            onPlayPractice(config)
        }
    }
}

public struct ModeLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    private let onPlay: @MainActor () -> Void
    private let onDaily: @MainActor () -> Void
    private let onChallenge: @MainActor () -> Void
    private let onCreate: @MainActor () -> Void
    private let onPractice: @MainActor () -> Void
    @State private var showGuidebook = false

    public init(
        onPlay: @escaping @MainActor () -> Void = {},
        onDaily: @escaping @MainActor () -> Void = {},
        onChallenge: @escaping @MainActor () -> Void = {},
        onCreate: @escaping @MainActor () -> Void = {},
        onPractice: @escaping @MainActor () -> Void = {}
    ) {
        self.onPlay = onPlay
        self.onDaily = onDaily
        self.onChallenge = onChallenge
        self.onCreate = onCreate
        self.onPractice = onPractice
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Play") {
                    ModeActionRow(title: "Game", subtitle: "Resume your main game.", systemImage: "play.circle.fill", action: onPlay)
                    ModeActionRow(title: "Daily Rewards", subtitle: "Claim today's reward and catch up missed days.", systemImage: "calendar.circle.fill", action: onDaily)
                    ModeActionRow(title: "Challenge Mode", subtitle: "Play curated boards with specific targets.", systemImage: "flag.checkered.circle.fill", action: onChallenge)
                    ModeActionRow(title: "Create a Game", subtitle: "Design a custom challenge and test it.", systemImage: "slider.horizontal.3", action: onCreate)
                }
                Section("Learn") {
                    ModeActionRow(title: "Practice Hub", subtitle: "Review moves, mistakes, and timed drills.", systemImage: "target", action: onPractice)
                    ModeActionRow(title: "Guidebook", subtitle: "Rules, tiles, valid moves, and perks.", systemImage: "book.closed.fill") {
                        showGuidebook = true
                    }
                }
            }
            .navigationTitle("Modes")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showGuidebook) {
                HowToPlayView()
            }
        }
        .trackScreen(.modes)
    }
}

public struct SocialFeedView: View {
    @Environment(\.socialService) private var socialService
    @Environment(\.dismiss) private var dismiss
    @State private var items: [SocialFeedItem] = []
    @State private var selectedItem: SocialFeedItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddEvent = false
    
    enum FeedSection: String, CaseIterable, Identifiable {
        case global = "Global"
        case myPosts = "My Posts"
        var id: String { rawValue }
    }
    @State private var selectedSection: FeedSection = .global
    
    @State private var itemToDelete: SocialFeedItem?
    @State private var showDeleteAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "Feed unavailable",
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage)
                        )
                    } else if items.isEmpty {
                        ContentUnavailableView(
                            "No feed updates yet",
                            systemImage: "person.2.wave.2",
                            description: Text("Ultimate2244 will show real friend and community updates here when they are available.")
                        )
                    } else {
                        let filteredItems = selectedSection == .global 
                            ? items 
                            : items.filter { $0.authorName == (UserDefaults.standard.string(forKey: "profilePlayerName") ?? "Player") }
                        
                        if filteredItems.isEmpty {
                            ContentUnavailableView(
                                "No posts yet",
                                systemImage: "person.text.rectangle",
                                description: Text("You haven't posted any updates yet.")
                            )
                        } else {
                            ForEach(filteredItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    FeedItemRow(item: Binding(
                                        get: { item },
                                        set: { newValue in
                                            if let idx = items.firstIndex(where: { $0.id == newValue.id }) {
                                                items[idx] = newValue
                                            }
                                        }
                                    ))
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    if item.authorName == (UserDefaults.standard.string(forKey: "profilePlayerName") ?? "Player") {
                                        Button(role: .destructive) {
                                            itemToDelete = item
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Picker("Feed Section", selection: $selectedSection) {
                        ForEach(FeedSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .textCase(nil)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle("Feed")
            .platformNavigationTitleDisplayMode(.inline)
            .alert("Delete Post?", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await socialService.deleteItem(itemID: item.id)
                        items.removeAll { $0.id == item.id }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Are you sure you want to delete this post? This will also delete any comments and reactions.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .platformTopBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $selectedItem) { item in
                FeedCommentsView(item: item, onDismiss: {
                    await load()
                })
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventSheet(socialService: socialService) {
                    Task { await load() }
                }
            }
        }
        .trackScreen(.socialFeed)
    }

    private func load() async {
        let showLoading = items.isEmpty
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }
        do {
            items = try await socialService.feed()
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Add Event Sheet

private struct AddEventSheet: View {
    let socialService: any SocialService
    let onPosted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var statText = ""
    @State private var isPosting = false
    @State private var postError: String?

    private var canPost: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Message")
                } footer: {
                    Text("Share a milestone, streak, challenge time, or HoF infinity count with the community.")
                }

                Section("Status Tag (optional)") {
                    TextField("e.g. New record · Game", text: $statText)
                }

                if let postError {
                    Section {
                        Label(postError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Event")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await post() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canPost)
                }
            }
        }
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }
        do {
            let finalStat = statText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "📝 Player update"
                : statText.trimmingCharacters(in: .whitespacesAndNewlines)
            try await socialService.postEvent(
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                statText: finalStat
            )
            postError = nil
            onPosted()
            dismiss()
        } catch {
            postError = error.localizedDescription
        }
    }
}

public struct FriendsView: View {
    @Environment(\.socialService) private var socialService
    @Environment(\.accountService) private var accountService
    @Environment(\.profileClient) private var profileClient
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [AccountProfile] = []
    @State private var invites: [FamilyInvite] = []
    @State private var currentProfile: AccountProfile?
    @State private var localFriendCode: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var inviteToRemove: FamilyInvite?
    @State private var showUninviteAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Your friend code") {
                    HStack {
                        Image(systemName: "qrcode")
                            .font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(currentProfile?.friendCode ?? localFriendCode ?? "...")
                                .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        }
                    }
                }
                Section("Search") {
                    TextField("Name or friend code", text: $query)
                        .platformTextInputAutocapitalizationNever()
                    Button("Search") {
                        Task { await search() }
                    }
                    .disabled(isLoading)
                }
                Section("Results") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "Friends unavailable",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(errorMessage)
                        )
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "No players found",
                            systemImage: "magnifyingglass",
                            description: Text("Search by exact friend code or the start of a username.")
                        )
                    } else {
                        ForEach(results, id: \.uid) { profile in
                            FriendProfileRow(profile: profile)
                        }
                    }
                }
                Section {
                    if invites.isEmpty {
                        Text("No family invites yet.")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(invites) { invite in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(invite.displayName)
                                    Text(invite.emailOrCode)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Uninvite") {
                                    inviteToRemove = invite
                                    showUninviteAlert = true
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await load()
            }
        }
        .trackScreen(.friends)
        .alert("Are you sure you want to uninvite this player? They will be removed immediately.", isPresented: $showUninviteAlert) {
            Button("Yes", role: .destructive) {
                if let invite = inviteToRemove {
                    invites.removeAll { $0.id == invite.id }
                    Task {
                        try? await socialService.removeInvite(id: invite.id)
                    }
                }
                inviteToRemove = nil
            }
            Button("No", role: .cancel) {
                inviteToRemove = nil
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        currentProfile = await accountService.currentState().profile

        // Always have a friend code available, even without auth
        if currentProfile?.friendCode == nil {
            localFriendCode = (try? await profileClient.fetchProfile())?.friendCode
        }

        do {
            invites = try await socialService.invites()
            results = try await socialService.searchFriends(query: query)
            errorMessage = nil
        } catch {
            invites = []
            results = []
            errorMessage = error.localizedDescription
        }
    }

    private func search() async {
        isLoading = true
        defer { isLoading = false }

        do {
            results = try await socialService.searchFriends(query: query)
            errorMessage = nil
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}

public struct AccountCenterView: View {
    @Environment(\.accountService) private var accountService
    @Environment(\.dismiss) private var dismiss
    @State private var state: AccountAuthState = .signedOut
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var username = ""
    @State private var phoneNumber = ""
    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let profile = state.profile {
                        HStack {
                            Image(systemName: profile.isAnonymous ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(profile.displayName)
                                    .font(.headline)
                                Text(profile.isAnonymous ? "Anonymous progress" : profile.email ?? profile.username)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Sign in or create an account to protect progress across devices.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sign in / create") {
                    TextField("Display name", text: $displayName)
                        .platformTextInputAutocapitalizationWords()
                    TextField("Email", text: $email)
                        .platformTextInputAutocapitalizationNever()
                    SecureField("Password", text: $password)
                    HStack {
                        Button("Sign in") { Task { await signIn() } }
                        Button("Create") { Task { await create() } }
                    }
                }

                Section("Profile") {
                    TextField("Username", text: $username)
                        .platformTextInputAutocapitalizationNever()
                    TextField("Phone number", text: $phoneNumber)
                    Button("Save profile") { Task { await saveProfile() } }
                    Button("Send email verification") { Task { await sendEmailVerification() } }
                }

                Section("Recovery") {
                    Button("Send password reset") { Task { await resetPassword() } }
                    Button("Sign out") { Task { await signOut() } }
                    Button("Delete account", role: .destructive) { showDeleteConfirm = true }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Account")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
            .confirmationDialog("Delete account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the current account profile from Ultimate2244. Cloud deletion requires Firebase Auth to be configured.")
            }
        }
        .trackScreen(.account)
    }

    private func load() async {
        state = await accountService.currentState()
        if let profile = state.profile {
            displayName = profile.displayName
            username = profile.username
            phoneNumber = profile.phoneNumber ?? ""
            email = profile.email ?? ""
        }
    }

    private func signIn() async {
        do {
            let profile = try await accountService.signIn(email: email, password: password)
            state = .signedIn(profile)
            statusMessage = "Signed in."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func create() async {
        do {
            let profile = try await accountService.createAccount(email: email, password: password, displayName: displayName)
            state = .signedIn(profile)
            statusMessage = "Account created."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveProfile() async {
        guard var profile = state.profile else { return }
        profile.displayName = displayName.isEmpty ? profile.displayName : displayName
        profile.username = username.isEmpty ? profile.username : username
        profile.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        do {
            let saved = try await accountService.updateProfile(profile)
            state = saved.isAnonymous ? .anonymous(saved) : .signedIn(saved)
            statusMessage = "Profile saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func sendEmailVerification() async {
        do {
            try await accountService.sendEmailVerification()
            statusMessage = "Verification email sent."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func resetPassword() async {
        do {
            try await accountService.sendPasswordReset(email: email)
            statusMessage = "Password reset email sent."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        do {
            try await accountService.signOut()
            await load()
            statusMessage = "Signed out."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        do {
            try await accountService.deleteAccount()
            await load()
            statusMessage = "Account deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

public struct SubscriptionCenterView: View {
    @Environment(\.purchaseService) private var purchaseService
    @Environment(\.socialService) private var socialService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanID = IAPProduct.proYearlyProduct.id
    @State private var statusMessage: String?
    @State private var invites: [FamilyInvite] = []
    @State private var showCancelSurvey = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard(title: "Ultimate2244 Pro", subtitle: "Premium practice, no ads, auto-claim boosts, and family plan options.", systemImage: "sparkles")

                    ForEach(SubscriptionPlan.proPlans) { plan in
                        Button {
                            selectedPlanID = plan.id
                        } label: {
                            SubscriptionPlanCard(plan: plan, isSelected: selectedPlanID == plan.id)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task { await purchaseSelectedPlan() }
                    } label: {
                        Text("Start selected plan")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(purchaseService.isLoading)

                    Button("Restore purchases") {
                        Task { await purchaseService.restorePurchases() }
                    }
                    .buttonStyle(.bordered)

                    Button("Manage or cancel plan") {
                        showCancelSurvey = true
                    }
                    .buttonStyle(.bordered)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Family members")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                    ForEach(invites) { invite in
                        HStack {
                            Text(invite.displayName)
                            Spacer()
                            Text(invite.status)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassBackground(in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await purchaseService.loadProducts()
                invites = (try? await socialService.invites()) ?? []
            }
            .confirmationDialog("Why are you canceling?", isPresented: $showCancelSurvey, titleVisibility: .visible) {
                Button("Too expensive") { statusMessage = "Thanks for the feedback." }
                Button("I do not use Pro enough") { statusMessage = "Thanks for the feedback." }
                Button("I had a technical issue") { statusMessage = "Thanks for the feedback." }
                Button("Keep Pro", role: .cancel) {}
            }
        }
        .trackScreen(.subscription)
    }

    private func purchaseSelectedPlan() async {
        let success = await purchaseService.purchase(productID: selectedPlanID)
        statusMessage = success ? "Plan activated." : (purchaseService.errorMessage ?? "Purchase was not completed.")
    }
}

public struct ReminderSettingsView: View {
    @Environment(PlayerReadinessStore.self) private var readiness
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reminderNotificationScheduler) private var reminderNotificationScheduler
    @State private var store = ReminderPreferenceStore()
    @State private var authorizationStatus: ReminderNotificationAuthorizationStatus = .unavailable
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isApplying = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Notification permission") {
                    LabeledContent("Status", value: authorizationStatus.displayText)
                    if authorizationStatus == .notDetermined {
                        Button("Allow Notifications") {
                            Task { await requestNotificationPermission() }
                        }
                    }
                    if authorizationStatus == .denied {
                        Text("Notifications are off in iOS Settings. Turn them on there to receive Ultimate2244 reminders.")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.red)
                    }
                }
                Section("Reminders") {
                    Toggle("Practice reminder", isOn: $store.preferences.practiceReminderEnabled)
                    Toggle("Streak reminder", isOn: $store.preferences.streakReminderEnabled)
                    Toggle("Quest reminder", isOn: $store.preferences.questReminderEnabled)
                    Toggle("Smart scheduling", isOn: $store.preferences.smartSchedulingEnabled)
                }
                Section("Time") {
                    Stepper("Hour: \(store.preferences.reminderHour)", value: $store.preferences.reminderHour, in: 0...23)
                    Stepper("Minute: \(store.preferences.reminderMinute)", value: $store.preferences.reminderMinute, in: 0...59, step: 5)
                    Text("Current reminder time: \(store.preferences.displayTime)")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Restore default reminders") { store.reset() }
                    if isApplying {
                        ProgressView("Updating reminders")
                    }
                }
            }
            .navigationTitle("Reminders")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await refreshNotificationStatus()
                if authorizationStatus.allowsScheduling, store.preferences.hasEnabledReminder {
                    await persistAndApplyReminders()
                }
            }
            .onChange(of: store.preferences) { _, _ in
                Task { await persistAndApplyReminders() }
            }
            .onDisappear {
                readiness.updateReminderPreferences(store.preferences)
            }
        }
        .trackScreen(.reminders)
    }

    @MainActor
    private func refreshNotificationStatus() async {
        authorizationStatus = await reminderNotificationScheduler.authorizationStatus()
    }

    @MainActor
    private func requestNotificationPermission() async {
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        do {
            authorizationStatus = try await reminderNotificationScheduler.requestAuthorization()
            if authorizationStatus.allowsScheduling {
                try await reminderNotificationScheduler.apply(store.preferences)
                statusMessage = scheduleSummary
            } else {
                statusMessage = nil
                errorMessage = ReminderNotificationSchedulerError.permissionDenied.localizedDescription
            }
        } catch {
            await refreshNotificationStatus()
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func persistAndApplyReminders() async {
        readiness.updateReminderPreferences(store.preferences)
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        do {
            if store.preferences.hasEnabledReminder {
                try await reminderNotificationScheduler.apply(store.preferences)
                statusMessage = scheduleSummary
            } else {
                await reminderNotificationScheduler.cancelAll()
                statusMessage = "All notification reminders are off."
            }
            await refreshNotificationStatus()
        } catch {
            await refreshNotificationStatus()
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private var scheduleSummary: String {
        "Scheduled selected reminders for \(store.preferences.displayTime)."
    }
}

private extension ReminderNotificationAuthorizationStatus {
    var displayText: String {
        switch self {
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        case .authorized:
            "Allowed"
        case .provisional:
            "Provisionally allowed"
        case .ephemeral:
            "Temporarily allowed"
        case .unavailable:
            "Unavailable"
        }
    }
}

public struct WidgetPromoView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard(title: "Quick-start Ultimate2244", subtitle: "Widget and lock-screen ideas are represented as in-app shortcuts for daily claims, streaks, and challenges.", systemImage: "rectangle.on.rectangle")
                    ShortcutPreview(title: "Daily claim", subtitle: "Jump straight to today's reward.", systemImage: "calendar.badge.checkmark")
                    ShortcutPreview(title: "Streak saver", subtitle: "See when your streak needs attention.", systemImage: "flame.fill")
                    ShortcutPreview(title: "Challenge timer", subtitle: "Resume a timed run from the modes hub.", systemImage: "timer")
                }
                .padding()
            }
            .navigationTitle("Quick Start")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .trackScreen(.widgetPromo)
    }
}

public struct YearReviewView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(DailyClaimsStore.self) private var dailyClaimsStore
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        let summary = makeSummary()
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard(title: "\(summary.year) in Ultimate2244", subtitle: "A shareable look back at your board progress.", systemImage: "sparkles.rectangle.stack.fill")
                    ReviewMetric(title: "Highest tile", value: summary.highestTileLabel, systemImage: "crown.fill")
                    ReviewMetric(title: "Games played", value: "\(summary.gamesPlayed)", systemImage: "gamecontroller.fill")
                    ReviewMetric(title: "Total merges", value: "\(summary.totalMerges)", systemImage: "square.stack.3d.up.fill")
                    ReviewMetric(title: "Best streak", value: "\(summary.bestStreak) days", systemImage: "flame.fill")
                    ReviewMetric(title: "Rank", value: summary.rankText, systemImage: "trophy.fill")
                }
                .padding()
            }
            .navigationTitle("Year Review")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .trackScreen(.yearReview)
    }

    private func makeSummary() -> YearReviewSummary {
        YearReviewSummary(
            gamesPlayed: UserDefaults.standard.integer(forKey: "gamesPlayed"),
            highestTileLabel: TileStepLabelFormatter.labelForStep(gameStore.state.highestTileStep),
            totalMerges: gameStore.state.moves,
            dailyClaims: dailyClaimsStore.currentStreak,
            bestStreak: dailyClaimsStore.currentStreak,
            rankText: UserLeaderboardData.globalRank > 0 ? "#\(UserLeaderboardData.globalRank)" : "Unranked"
        )
    }
}

public struct ProCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var moveStore = MoveReviewStore()

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Coach") {
                    Text("Pro Coach uses deterministic 2244 rules: valid path count, chain length, board space, and power-up value. It does not call an AI service.")
                        .foregroundStyle(.secondary)
                }
                Section("Move explanations") {
                    ForEach(moveStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.moveSummary)
                                .font(.headline)
                            Text(entry.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pro Coach")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { moveStore.seedIfEmpty() }
        }
        .trackScreen(.proCoach)
    }
}

private struct OnboardingStepLayout<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 92, height: 92)
                    .background(Color.green.opacity(0.12), in: Circle())
                Text(title)
                    .font(.avenirNext(size: GameFonts.title1Size, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                content
            }
            .padding(24)
        }
    }
}

private struct ChoiceRow: View {
    let title: String
    var detail: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct ModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(title)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
            Text(subtitle)
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding()
        .glassBackground(in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ModeActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}

private struct ReviewEntryRow: View {
    let entry: MoveReviewEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.moveSummary)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .bold))
            Text(entry.outcome)
                .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MoveReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: MoveReviewEntry

    var body: some View {
        NavigationStack {
            List {
                Section("Move") { Text(entry.moveSummary) }
                Section("Board") { Text(entry.boardSummary) }
                Section("Explanation") { Text(entry.explanation) }
                Section("Outcome") { Text(entry.outcome) }
            }
            .navigationTitle("Move Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct FeedItemRow: View {
    @Environment(\.socialService) private var socialService
    @Binding var item: SocialFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(item.avatarID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.authorName)
                            .font(.headline)
                        Text(relativeTime(from: item.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    let statParts = item.statText.components(separatedBy: "|")
                    if statParts.count == 2 {
                        Label(statParts[1], systemImage: statParts[0])
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(eventColor.opacity(0.15))
                            .foregroundStyle(eventColor)
                            .clipShape(Capsule())
                    } else {
                        Text(item.statText)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(eventColor.opacity(0.15))
                            .foregroundStyle(eventColor)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            Text(item.message)
                .font(.subheadline)
            HStack(spacing: 16) {
                Button {
                    let wasHearted = item.isHearted ?? false
                    item.isHearted = !wasHearted
                    item.reactionCount += (wasHearted ? -1 : 1)
                    
                    Task {
                        try? await socialService.toggleItemHeart(itemID: item.id)
                    }
                } label: {
                    Label("\(item.reactionCount)", systemImage: (item.isHearted ?? false) ? "heart.fill" : "heart")
                        .foregroundColor((item.isHearted ?? false) ? .red : .secondary)
                }
                .buttonStyle(.borderless)

                Label("\(item.commentCount)", systemImage: "bubble.right")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }

    private var eventColor: Color {
        let stat = item.statText.lowercased()
        if stat.contains("tile") || stat.contains("endless") || stat.contains("milestone") || stat.contains("record") || stat.contains("personal") || stat.contains("breakthrough") {
            return .blue
        } else if stat.contains("challenge") || stat.contains("speed") || stat.contains("timed") {
            return .orange
        } else if stat.contains("streak") {
            return .red
        } else if stat.contains("hall of fame") || stat.contains("hof") || stat.contains("legendary") {
            return .yellow
        } else if stat.contains("theme") || stat.contains("style") || stat.contains("customization") {
            return .purple
        } else if stat.contains("quest") || stat.contains("chest") {
            return .green
        }
        return .secondary
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}

private struct FeedCommentsView: View {
    @Environment(\.socialService) private var socialService
    @Environment(\.dismiss) private var dismiss
    @State private var item: SocialFeedItem
    @State private var comment = ""
    /// Ticks forward so future-dated comments appear over time
    @State private var refreshTick = Date()
    private let commentTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    @State private var activeCommentTasks: [Task<Void, Never>] = []
    let onDismiss: () async -> Void

    init(item: SocialFeedItem, onDismiss: @escaping () async -> Void) {
        self._item = State(initialValue: item)
        self.onDismiss = onDismiss
    }

    /// Only show comments whose timestamp has already passed, but always show player comments immediately
    private var visibleCommentIndices: [Int] {
        item.comments.indices.filter { item.comments[$0].createdAt <= refreshTick || item.comments[$0].authorName == "Player" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Post") {
                    FeedItemRow(item: $item)
                }
                Section("Comments (\(visibleCommentIndices.count))") {
                    ForEach(visibleCommentIndices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(item.comments[idx].avatarID)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                        Text(item.comments[idx].authorName)
                                            .font(.caption)
                                            .bold()
                                        Spacer()
                                        Text(formatDate(item.comments[idx].createdAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.comments[idx].text)
                                        .font(.system(size: 15))
                                }
                                
                                Spacer()
                                
                                Button {
                                    let wasHearted = item.comments[idx].isHearted ?? false
                                    item.comments[idx].isHearted = !wasHearted
                                    let currentLikes = item.comments[idx].likes ?? 0
                                    item.comments[idx].likes = currentLikes + (wasHearted ? -1 : 1)
                                    
                                    Task {
                                        try? await socialService.toggleCommentHeart(itemID: item.id, commentID: item.comments[idx].id)
                                    }
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: (item.comments[idx].isHearted ?? false) ? "heart.fill" : "heart")
                                            .foregroundColor((item.comments[idx].isHearted ?? false) ? .red : .secondary)
                                            .font(.footnote)
                                        
                                        if let likes = item.comments[idx].likes, likes > 0 {
                                            Text("\(likes)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 8)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            comment = "@\(item.comments[idx].authorName) "
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        TextField("Add a comment...", text: $comment)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                submitComment()
                            }
                        
                        Button(action: submitComment) {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                        }
                        .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderless)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("Comments")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .onReceive(commentTimer) { _ in
            refreshTick = Date()
        }
        .onDisappear {
            Task {
                for task in activeCommentTasks {
                    _ = await task.result
                }
                await onDismiss()
            }
        }
    }
    
    private func submitComment() {
        guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = comment
        comment = ""
        
        let replyDate = Date()
        let newComment = SocialFeedComment(authorName: "Player", text: text, createdAt: replyDate)
        item.comments.append(newComment)
        item.comments.sort { $0.createdAt < $1.createdAt }
        item.commentCount = item.comments.count
        
        refreshTick = Date()
        
        let task = Task {
            _ = try? await socialService.addComment(to: item.id, text: text)
        }
        activeCommentTasks.append(task)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct FriendProfileRow: View {
    let profile: AccountProfile
    @State private var isFollowing = false

    var body: some View {
        HStack {
            Image(profile.avatarID)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(profile.displayName)
                Text(profile.friendCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(isFollowing ? "Following" : "Follow") {
                isFollowing.toggle()
            }
            .buttonStyle(.bordered)
            .tint(isFollowing ? .secondary : .accentColor)
        }
    }
}

private struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(plan.displayName)
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                    Text("\(plan.priceText) · \(plan.periodText)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if plan.isRecommended {
                    Text("Recommended")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            ForEach(plan.benefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark")
                    .font(.caption)
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ShortcutPreview: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .glassBackground(in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
            }
            Spacer()
        }
        .padding()
        .glassBackground(in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
@ViewBuilder
private func heroCard(title: String, subtitle: String, systemImage: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Image(systemName: systemImage)
            .font(.largeTitle)
            .foregroundStyle(.green)
        Text(title)
            .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
        Text(subtitle)
            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .glassBackground(in: RoundedRectangle(cornerRadius: 16))
}

#if DEBUG
#Preview("Onboarding") {
    GameUIScreenPreviewHost {
        OnboardingFlowView(onComplete: { _ in })
    }
}

#Preview("Practice Hub") {
    GameUIScreenPreviewHost {
        PracticeHubView()
    }
}

#Preview("Mode Library") {
    GameUIScreenPreviewHost {
        ModeLibraryView()
    }
}

#Preview("Social Feed") {
    GameUIScreenPreviewHost {
        SocialFeedView()
    }
}

#Preview("Friends") {
    GameUIScreenPreviewHost {
        FriendsView()
    }
}

#Preview("Account Center") {
    GameUIScreenPreviewHost {
        AccountCenterView()
    }
}

#Preview("Subscription Center") {
    GameUIScreenPreviewHost {
        SubscriptionCenterView()
    }
}

#Preview("Reminder Settings") {
    GameUIScreenPreviewHost {
        ReminderSettingsView()
    }
}

#Preview("Widget Promo") {
    GameUIScreenPreviewHost {
        WidgetPromoView()
    }
}

#Preview("Year Review") {
    GameUIScreenPreviewHost {
        YearReviewView()
    }
}

#Preview("Pro Coach") {
    GameUIScreenPreviewHost {
        ProCoachView()
    }
}
#endif
