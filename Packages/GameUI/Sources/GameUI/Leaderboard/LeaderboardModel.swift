import Foundation
import SwiftUI

@MainActor
@Observable
public final class LeaderboardModel {
    // State
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var entries: [LeaderboardEntry] = []
    public private(set) var myEntry: LeaderboardEntry?
    public private(set) var totalPlayers: Int?
    public private(set) var error: String?
    private var isRefreshing = false
    
    // Filters
    public var selectedPeriod: LeaderboardPeriod = .week {
        didSet { if oldValue != selectedPeriod { Task { await refresh() } } }
    }
    public var selectedFilter: LeaderboardFilter = .global {
        didSet {
            if oldValue != selectedFilter {
                // Populate data synchronously for instant switching (no loading spinner)
                if let page = client.initialDataForFilter?(selectedFilter) {
                    entries = page.entries
                    myEntry = page.myEntry
                    if let tp = page.totalPlayers { totalPlayers = tp }
                }
                Task { await refresh() }
            }
        }
    }
    
    // Pagination
    private var nextCursor: String?
    private let pageSize = 50
    
    // Dependencies
    private let client: LeaderboardClient
    
    public init(client: LeaderboardClient) {
        self.client = client
        // Pre-populate data synchronously so the first frame renders instantly
        if let page = client.initialData?() {
            self.entries = page.entries
            self.myEntry = page.myEntry
            self.totalPlayers = page.totalPlayers
            self.nextCursor = page.nextCursor
        }
    }
    
    public func authenticate() async {
        do {
            _ = try await client.authenticate()
        } catch {
            self.error = "Failed to authenticate: \(error.localizedDescription)"
        }
    }
    
    public func submitScore(_ score: Int) async {
        do {
            try await client.submitScore(score)
            // Refresh to show updated position
            await refresh()
        } catch {
            self.error = "Failed to submit score: \(error.localizedDescription)"
        }
    }
    
    public func submitInfinityCount(_ count: Int) async {
        do {
            try await client.submitInfinityCount(count)
            // Refresh to show updated position in Hall of Fame
            if selectedFilter == .hallOfFame {
                await refresh()
            }
        } catch {
            self.error = "Failed to submit infinity count: \(error.localizedDescription)"
        }
    }
    
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        error = nil
        
        do {
            // Fetch new data while keeping old data visible (no spinner)
            let page = try await client.fetchPage(
                selectedPeriod,
                selectedFilter,
                nil,
                pageSize
            )
            
            // Swap in new data atomically
            entries = page.entries
            myEntry = page.myEntry
            nextCursor = page.nextCursor
            totalPlayers = page.totalPlayers
            
            // If we don't have our entry in the current page, fetch it separately
            if myEntry == nil {
                myEntry = try? await client.fetchMyRank(selectedPeriod, selectedFilter)
            }
        } catch {
            self.error = "Failed to load leaderboard: \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
    
    public func loadMore() async {
        guard !isLoadingMore, let cursor = nextCursor else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let page = try await client.fetchPage(
                selectedPeriod,
                selectedFilter,
                cursor,
                pageSize
            )
            
            entries.append(contentsOf: page.entries)
            nextCursor = page.nextCursor
            
            // Update my entry if it's in this page
            if let newMyEntry = page.myEntry {
                myEntry = newMyEntry
            }
        } catch {
            self.error = "Failed to load more: \(error.localizedDescription)"
        }
    }
    
    public var canLoadMore: Bool {
        nextCursor != nil && !isLoadingMore
    }
    
    public var hasData: Bool {
        !entries.isEmpty
    }
    
    // Helper to format large numbers
    public static func formatScore(_ score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }
    
    // Helper to get rank suffix
    public static func rankSuffix(for rank: Int) -> String {
        let lastDigit = rank % 10
        let lastTwoDigits = rank % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }
        
        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    public static func formatRank(_ rank: Int) -> String {
        "\(rank)\(rankSuffix(for: rank))"
    }
}
