import Foundation

enum AppPreferences {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Key {
        static let username = "username"
        static let password = "password"
        static let cookie = "cookie"
        static let accountHistory = "account_history"
        static let dataVersion = "data_version"
        static let lastChartStatsUpdate = "last_chart_stats_update"
        static let enableAliasSearch = "enable_alias_search"
        static let enableCharterSearch = "enable_charter_search"
        static let enableShowAlias = "enable_show_alias"
        static let enableDivingFishNickname = "enable_diving_fish_nickname"
        static let divingFishNickname = "diving_fish_nickname"
        static let lastQueryLevel = "last_query_level"
        static let lastQueryVersion = "last_query_version"
        static let searchHistory = "search_history"
        static let favorites = "favorites"
    }

    // MARK: - User Info
    static var username: String {
        get { defaults.string(forKey: Key.username) ?? "" }
        set { defaults.set(newValue, forKey: Key.username) }
    }

    static var password: String {
        get { defaults.string(forKey: Key.password) ?? "" }
        set { defaults.set(newValue, forKey: Key.password) }
    }

    static var cookie: String {
        get { defaults.string(forKey: Key.cookie) ?? "" }
        set { defaults.set(newValue, forKey: Key.cookie) }
    }

    static func saveLoginInfo(username: String, password: String, cookie: String) {
        Self.username = username
        Self.password = password
        Self.cookie = cookie
        addAccountToHistory(username: username, password: password)
    }

    static var accountHistory: [(username: String, password: String)] {
        get {
            guard let data = defaults.data(forKey: Key.accountHistory),
                  let array = try? JSONDecoder().decode([[String: String]].self, from: data) else {
                return []
            }
            return array.compactMap { entry in
                guard let username = entry["username"], let password = entry["password"] else { return nil }
                return (username, password)
            }
        }
        set {
            let array = newValue.map { ["username": $0.username, "password": $0.password] }
            if let data = try? JSONEncoder().encode(array) {
                defaults.set(data, forKey: Key.accountHistory)
            }
        }
    }

    static func addAccountToHistory(username: String, password: String) {
        var history = accountHistory
        if !history.contains(where: { $0.username == username }) {
            history.append((username: username, password: password))
            accountHistory = history
        }
    }

    static func removeAccount(username: String) {
        accountHistory = accountHistory.filter { $0.username != username }
    }

    /// Clear all login state (cookie, username, password) to allow switching
    /// to a different account or logging out entirely.
    static func logout() {
        cookie = ""
        username = ""
        password = ""
    }

    // MARK: - Data Version
    static var dataVersion: String {
        get { defaults.string(forKey: Key.dataVersion) ?? "0" }
        set { defaults.set(newValue, forKey: Key.dataVersion) }
    }

    static var lastChartStatsUpdate: TimeInterval {
        get { defaults.double(forKey: Key.lastChartStatsUpdate) }
        set { defaults.set(newValue, forKey: Key.lastChartStatsUpdate) }
    }

    // MARK: - Settings
    static var enableAliasSearch: Bool {
        get { defaults.bool(forKey: Key.enableAliasSearch) }
        set { defaults.set(newValue, forKey: Key.enableAliasSearch) }
    }

    static var enableCharterSearch: Bool {
        get { defaults.bool(forKey: Key.enableCharterSearch) }
        set { defaults.set(newValue, forKey: Key.enableCharterSearch) }
    }

    static var enableShowAlias: Bool {
        get { defaults.bool(forKey: Key.enableShowAlias) }
        set { defaults.set(newValue, forKey: Key.enableShowAlias) }
    }

    static var enableDivingFishNickname: Bool {
        get { defaults.bool(forKey: Key.enableDivingFishNickname) }
        set { defaults.set(newValue, forKey: Key.enableDivingFishNickname) }
    }

    static var divingFishNickname: String {
        get { defaults.string(forKey: Key.divingFishNickname) ?? "" }
        set { defaults.set(newValue, forKey: Key.divingFishNickname) }
    }

    static var lastQueryLevel: Float {
        get { defaults.object(forKey: Key.lastQueryLevel) as? Float ?? 18 }
        set { defaults.set(newValue, forKey: Key.lastQueryLevel) }
    }

    static var lastQueryVersion: Int {
        get { defaults.integer(forKey: Key.lastQueryVersion) }
        set { defaults.set(newValue, forKey: Key.lastQueryVersion) }
    }

    // MARK: - Search History
    static var searchHistory: [String] {
        get { defaults.stringArray(forKey: Key.searchHistory) ?? [] }
        set { defaults.set(newValue, forKey: Key.searchHistory) }
    }

    static func saveSearchHistory(_ query: String) {
        var history = searchHistory
        history.removeAll { $0 == query }
        history.insert(query, at: 0)
        if history.count > 30 {
            history.removeLast()
        }
        searchHistory = history
    }

    static func clearSearchHistory() {
        searchHistory = []
    }

    // MARK: - Favorites
    static var favoriteIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.favorites) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.favorites) }
    }

    static func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    static func setFavorite(id: String, isFavorite: Bool) {
        var ids = favoriteIDs
        if isFavorite {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        favoriteIDs = ids
    }
}
