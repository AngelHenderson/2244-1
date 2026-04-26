import Foundation

/// Manages the rotating weekly "Best Offer" system
/// Offers rotate on a 5-week cycle, changing every Sunday at midnight
public struct WeeklyOfferManager: Sendable {

    /// A weekly offer with its contents and price
    public struct WeeklyOffer: Sendable, Equatable, Identifiable {
        public var id: String
        public var title: String
        public var price: Double
        public var noAds: Bool
        public var noAdsLifetime: Bool
        public var gems: Int?
        public var hammers: Int?
        public var swaps: Int?
        public var magnets: Int?
        public var spins: Int?
        public var boost2x: Int?
        public var boost3x: Int?
        public var boost4x: Int?

        public init(
            id: String,
            title: String,
            price: Double,
            noAds: Bool = false,
            noAdsLifetime: Bool = false,
            gems: Int? = nil,
            hammers: Int? = nil,
            swaps: Int? = nil,
            magnets: Int? = nil,
            spins: Int? = nil,
            boost2x: Int? = nil,
            boost3x: Int? = nil,
            boost4x: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.price = price
            self.noAds = noAds
            self.noAdsLifetime = noAdsLifetime
            self.gems = gems
            self.hammers = hammers
            self.swaps = swaps
            self.magnets = magnets
            self.spins = spins
            self.boost2x = boost2x
            self.boost3x = boost3x
            self.boost4x = boost4x
        }

        /// Formatted price string
        public var formattedPrice: String {
            String(format: "$%.2f", price)
        }

        /// Summary of contents for display
        public var contentsSummary: String {
            var parts: [String] = []
            if noAdsLifetime { parts.append("No Ads Lifetime") }
            else if noAds { parts.append("No Ads") }
            if let gems = gems { parts.append("\(gems.formatted()) Gems") }
            if let hammers = hammers { parts.append("\(hammers) Hammers") }
            if let swaps = swaps { parts.append("\(swaps) Swaps") }
            if let magnets = magnets { parts.append("\(magnets) MegaMerges") }
            if let spins = spins { parts.append("\(spins) Spins") }
            if let boost2x = boost2x { parts.append("\(boost2x) 2X Boost") }
            if let boost3x = boost3x { parts.append("\(boost3x) 3X Boost") }
            if let boost4x = boost4x { parts.append("\(boost4x) 4X Boost") }
            return parts.joined(separator: ", ")
        }
    }

    /// The 5 rotating weekly offers
    public static let offers: [WeeklyOffer] = [
        // Week 1: Premium Bundle
        WeeklyOffer(
            id: "weekly_premium_bundle",
            title: "Premium Bundle",
            price: 89.99,
            noAds: true,
            gems: 75000,
            hammers: 50,
            swaps: 30,
            magnets: 20,
            spins: 35,
            boost2x: 30,
            boost3x: 20,
            boost4x: 10
        ),
        // Week 2: Tools Starter
        WeeklyOffer(
            id: "weekly_tools_starter",
            title: "Tools Starter",
            price: 19.99,
            hammers: 10,
            swaps: 10,
            magnets: 10,
            spins: 10
        ),
        // Week 3: Mega Gems & Tools
        WeeklyOffer(
            id: "weekly_mega_gems_tools",
            title: "Mega Gems & Tools",
            price: 149.99,
            gems: 1000000,
            hammers: 500,
            swaps: 450,
            magnets: 400
        ),
        // Week 4: Boost Bonanza
        WeeklyOffer(
            id: "weekly_boost_bonanza",
            title: "Boost Bonanza",
            price: 124.99,
            boost2x: 500,
            boost3x: 400,
            boost4x: 300
        ),
        // Week 5: Ultimate Value
        WeeklyOffer(
            id: "weekly_ultimate_value",
            title: "Ultimate Value",
            price: 74.99,
            noAdsLifetime: true,
            gems: 100000,
            hammers: 100,
            swaps: 75,
            magnets: 50
        )
    ]

    /// Reference date: Sunday, January 26, 2026 is the start of Week 1
    /// Week 1 ends Saturday January 31, 2026 at 11:59:59 PM
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 26
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    /// Returns the current weekly offer based on today's date
    public static func currentOffer(for date: Date = Date()) -> WeeklyOffer {
        let weekIndex = weekNumber(for: date)
        return offers[weekIndex]
    }

    /// Returns the week number (0-4) for a given date
    public static func weekNumber(for date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let daysSinceReference = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0

        // If before reference date, return week 0
        if daysSinceReference < 0 {
            return 0
        }

        // Each week is 7 days, cycle through 5 weeks
        let weeksSinceReference = daysSinceReference / 7
        return weeksSinceReference % offers.count
    }

    /// Returns the deadline for the current offer (Saturday 11:59:59 PM)
    public static func currentOfferDeadline(for date: Date = Date()) -> Date {
        let calendar = Calendar.current

        // Find the next Saturday
        var nextSaturday = date
        while calendar.component(.weekday, from: nextSaturday) != 7 { // 7 = Saturday
            nextSaturday = calendar.date(byAdding: .day, value: 1, to: nextSaturday) ?? nextSaturday
        }

        // Set to 11:59:59 PM
        var components = calendar.dateComponents([.year, .month, .day], from: nextSaturday)
        components.hour = 23
        components.minute = 59
        components.second = 59

        return calendar.date(from: components) ?? nextSaturday
    }

    /// Returns a formatted countdown string (e.g., "2d 5h 30m")
    public static func countdownString(to deadline: Date, from date: Date = Date()) -> String {
        let interval = deadline.timeIntervalSince(date)
        guard interval > 0 else { return "Expired" }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Auto-Present Persistence

    private static let lastAutoPresentedKey = "weeklyOffer.lastAutoPresentedWeek"

    /// ISO-week identifier ("2026-17"). Use the ISO calendar so week boundaries
    /// land on Monday and roll over correctly across year boundaries.
    public static func weekIdentifier(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return "\(year)-\(String(format: "%02d", week))"
    }

    /// Returns true if the offer has not yet been auto-presented during the
    /// current ISO week. Manual taps on the SALE OFFER button bypass this
    /// gate so the user can re-open the sheet at will.
    public static func shouldAutoPresent(defaults: UserDefaults = .standard, date: Date = Date()) -> Bool {
        let current = weekIdentifier(for: date)
        let last = defaults.string(forKey: lastAutoPresentedKey)
        return last != current
    }

    /// Records that the offer was auto-presented in the current ISO week.
    /// Call this immediately when triggering the auto-present so a quick
    /// dismiss + re-appear cycle does not cause a second presentation.
    public static func markAutoPresented(defaults: UserDefaults = .standard, date: Date = Date()) {
        defaults.set(weekIdentifier(for: date), forKey: lastAutoPresentedKey)
    }
}
