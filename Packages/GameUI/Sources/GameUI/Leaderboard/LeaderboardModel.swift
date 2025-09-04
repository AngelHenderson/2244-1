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
    
    // Filters
    public var selectedPeriod: LeaderboardPeriod = .week {
        didSet { if oldValue != selectedPeriod { Task { await refresh() } } }
    }
    public var selectedFilter: LeaderboardFilter = .global {
        didSet { if oldValue != selectedFilter { Task { await refresh() } } }
    }
    
    // Pagination
    private var nextCursor: String?
    private let pageSize = 50
    
    // Dependencies
    private let client: LeaderboardClient
    
    public init(client: LeaderboardClient) {
        self.client = client
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
    
    public func refresh() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // Clear existing data
        nextCursor = nil
        entries.removeAll()
        myEntry = nil
        totalPlayers = nil
        
        do {
            // Fetch first page
            let page = try await client.fetchPage(
                selectedPeriod,
                selectedFilter,
                nil,
                pageSize
            )
            
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
        formatter.groupingSeparator = ","
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
