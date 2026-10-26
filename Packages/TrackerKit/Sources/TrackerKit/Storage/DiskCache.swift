import Foundation

/// Saves the last good snapshot per profile as JSON, so cards still show when offline.
/// Never stores tokens.
public struct DiskCache: Sendable {
    /// How long name and avatar from the REST API stay fresh (the API allows only 60 calls/hour without a token).
    public static let profileLifetime: TimeInterval = 24 * 3600

    struct Record: Codable {
        var snapshot: ProfileSnapshot
        var profileFetchedAt: Date
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/TrackerForGitHub/Cache` (inside the app's or widget's sandbox container).
    public static func standard() -> DiskCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return DiskCache(directory: base.appendingPathComponent("TrackerForGitHub/Cache", isDirectory: true))
    }

    private func url(for login: String) -> URL {
        directory.appendingPathComponent("\(login.lowercased()).json")
    }

    func record(for login: String) -> Record? {
        guard let data = try? Data(contentsOf: url(for: login)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Record.self, from: data)
    }

    public func snapshot(for login: String) -> ProfileSnapshot? {
        record(for: login)?.snapshot
    }

    /// The cached profile (name, avatar) if it's younger than 24 hours.
    public func freshProfile(for login: String, now: Date = Date()) -> GitHubProfile? {
        guard let r = record(for: login), now.timeIntervalSince(r.profileFetchedAt) < Self.profileLifetime else { return nil }
        return r.snapshot.profile
    }

    func save(_ snapshot: ProfileSnapshot, profileFetchedAt: Date) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Record(snapshot: snapshot, profileFetchedAt: profileFetchedAt))
            try data.write(to: url(for: snapshot.login), options: .atomic)
        } catch {
            // A failed cache write only costs offline support; never crash for it.
        }
    }

    public func remove(_ login: String) {
        try? FileManager.default.removeItem(at: url(for: login))
    }
}
