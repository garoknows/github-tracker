import Foundation

/// What a card shows after a refresh: fresh data, or cached data plus the reason it isn't fresh.
public struct LoadResult: Sendable {
    public let snapshot: ProfileSnapshot?
    /// Set when the network failed; `snapshot` is then the cached copy (if any).
    public let error: TrackerError?

    public var isOffline: Bool { error != nil && snapshot != nil }
}

/// Puts the pieces together: public HTML first, GraphQL when a token exists and the public path fails,
/// REST for name and avatar (cached 24 h), and the disk cache as the offline fallback.
public struct ProfileLoader: Sendable {
    public let client: GitHubClient
    public let cache: DiskCache
    public let tokens: TokenStore
    let now: @Sendable () -> Date

    public init(client: GitHubClient = GitHubClient(), cache: DiskCache = .standard(),
                tokens: TokenStore = KeychainTokenStore(), now: @escaping @Sendable () -> Date = Date.init) {
        self.client = client
        self.cache = cache
        self.tokens = tokens
        self.now = now
    }

    /// Checks a username exists (via the no-quota HTML endpoint) before adding it as a favorite.
    public func validate(_ login: String) async throws {
        _ = try await client.calendarHTML(for: login)
    }

    public func load(_ login: String) async -> LoadResult {
        do {
            return LoadResult(snapshot: try await fetch(login), error: nil)
        } catch let error as TrackerError {
            return LoadResult(snapshot: cache.snapshot(for: login), error: error)
        } catch {
            return LoadResult(snapshot: cache.snapshot(for: login), error: .markupChanged)
        }
    }

    func fetch(_ login: String) async throws -> ProfileSnapshot {
        let token = tokens.read()
        var graph: GitHubClient.GraphQLResult?

        // 1. Calendar: public HTML, falling back to GraphQL if parsing breaks.
        let calendar: ContributionCalendar
        do {
            calendar = try CalendarParser.parse(try await client.calendarHTML(for: login))
        } catch is CalendarParser.Failure {
            guard let token else { throw TrackerError.markupChanged }
            graph = try await client.graphQL(for: login, token: token)
            calendar = graph!.calendar
        }

        // 2. Activity overview: public profile first; GraphQL only when the public page doesn't have it.
        var overview: OverviewState
        do {
            overview = OverviewParser.parse(try await client.overviewHTML(for: login))
        } catch TrackerError.userNotFound(let l) {
            throw TrackerError.userNotFound(l)
        } catch {
            overview = .needsToken
        }
        if overview == .needsToken, let token {
            if graph == nil { graph = try? await client.graphQL(for: login, token: token) }
            if let g = graph { overview = .available(g.overview, source: .graphQL) }
        }

        // 3. Name and avatar: cached for 24 h; if REST is rate limited, a bare profile is fine.
        var profileFetchedAt = now()
        let profile: GitHubProfile
        if let fresh = cache.freshProfile(for: login, now: now()) {
            profile = fresh
            profileFetchedAt = cache.record(for: login)?.profileFetchedAt ?? profileFetchedAt
        } else if let g = graph {
            profile = g.profile
        } else {
            do {
                profile = try await client.profile(for: login, token: token)
            } catch {
                profile = cache.snapshot(for: login)?.profile ?? GitHubProfile(login: login, name: nil, avatarURL: nil)
                profileFetchedAt = .distantPast
            }
        }

        let snapshot = ProfileSnapshot(profile: profile, calendar: calendar, overview: overview, fetchedAt: now())
        cache.save(snapshot, profileFetchedAt: profileFetchedAt)
        return snapshot
    }
}
