import Foundation

/// What a card shows after a refresh: fresh data, or cached data plus the reason it isn't fresh.
public struct LoadResult: Sendable {
    public let snapshot: ProfileSnapshot?
    /// Set when the network failed; `snapshot` is then the cached copy (if any).
    public let error: TrackerError?
    /// Set when the Activity overview couldn't be refreshed; `snapshot` then carries the last good one.
    public let overviewError: TrackerError?
    /// True when `snapshot` holds daily counts guessed from the colors, because GitHub's hover text
    /// couldn't be read and nothing better was saved. Never written to the disk cache.
    public let estimated: Bool

    public init(snapshot: ProfileSnapshot?, error: TrackerError?, overviewError: TrackerError? = nil, estimated: Bool = false) {
        self.snapshot = snapshot
        self.error = error
        self.overviewError = overviewError
        self.estimated = estimated
    }

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
            let (snapshot, overviewError, estimated) = try await fetch(login)
            return LoadResult(snapshot: snapshot, error: estimated ? .countsUnreadable : nil,
                              overviewError: overviewError, estimated: estimated)
        } catch let error as TrackerError {
            return LoadResult(snapshot: cache.snapshot(for: login), error: error)
        } catch {
            return LoadResult(snapshot: cache.snapshot(for: login), error: .markupChanged)
        }
    }

    /// Fresh data, the error that stopped the Activity overview from refreshing (if any), and whether
    /// the daily counts are guesses (then nothing is saved).
    func fetch(_ login: String) async throws -> (ProfileSnapshot, TrackerError?, estimated: Bool) {
        let tokenLookup = tokens.lookup()
        let token = tokenLookup.token
        var graph: GitHubClient.GraphQLResult?

        // 1. Calendar: public HTML, falling back to GraphQL if parsing breaks.
        //    If only the per-day counts are missing, good saved data wins over guesses. With nothing
        //    saved, show the colors with guessed counts (marked as such) and never save them.
        let html = try await client.calendarHTML(for: login)
        let calendar: ContributionCalendar
        var estimated = false
        do {
            calendar = try CalendarParser.parse(html)
        } catch {
            if let token {
                let g = try await client.graphQL(for: login, token: token)
                graph = g
                calendar = g.calendar
            } else if error == .countsUnreadable, cache.snapshot(for: login) == nil {
                calendar = try CalendarParser.parse(html, estimateMissingCounts: true)
                estimated = true
            } else {
                throw error == .countsUnreadable ? TrackerError.countsUnreadable : TrackerError.markupChanged
            }
        }

        // 2. Activity overview: public profile first; GraphQL only when the public page doesn't have it.
        //    Only a page we couldn't read is a reason to ask for a token. A rate limit, server error or
        //    dropped connection keeps the last good overview (marked stale) until the next refresh,
        //    which the client already delays until GitHub's backoff has passed.
        var overview: OverviewState
        var overviewError: TrackerError?
        do {
            overview = OverviewParser.parse(try await client.overviewHTML(for: login))
        } catch TrackerError.userNotFound(let l) {
            throw TrackerError.userNotFound(l)
        } catch {
            overviewError = error as? TrackerError ?? .offline
            overview = .needsToken
        }
        if overviewError == nil, overview == .needsToken, let token {
            if graph == nil {
                do {
                    graph = try await client.graphQL(for: login, token: token)
                } catch TrackerError.userNotFound(let l) {
                    throw TrackerError.userNotFound(l)
                } catch TrackerError.invalidToken, TrackerError.markupChanged {
                    // The token or GraphQL's answer is the problem; the placeholder explains what to do.
                } catch {
                    overviewError = error as? TrackerError ?? .offline
                }
            }
            if let g = graph { overview = .available(g.overview, source: .graphQL) }
        }
        if overview == .needsToken, tokenLookup == .unreadable {
            overview = .tokenUnreadable
        }
        if overviewError != nil {
            overview = cache.snapshot(for: login)?.overview.keptAfterError ?? .unavailable
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
        if !estimated { cache.save(snapshot, profileFetchedAt: profileFetchedAt) }
        return (snapshot, overviewError, estimated)
    }
}

extension OverviewState {
    /// What to keep showing when a refresh of this state failed for a temporary reason.
    var keptAfterError: OverviewState? {
        switch self {
        case .available, .off: return self
        case .needsToken, .tokenUnreadable, .unavailable: return nil
        }
    }
}
