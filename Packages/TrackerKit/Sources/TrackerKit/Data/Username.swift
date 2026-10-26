import Foundation

public enum Username {
    public enum Problem: Error, Equatable, Sendable, LocalizedError {
        case empty
        case invalid(String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Type a GitHub username, like garoknows."
            case .invalid(let input):
                return "'\(input)' isn't a valid GitHub username. Use letters, numbers and single hyphens."
            }
        }
    }

    /// Turns "name", "@name", "github.com/name" or "https://github.com/name/repo" into "name".
    public static func normalize(_ raw: String) throws(Problem) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { throw .empty }

        if s.hasPrefix("@") { s.removeFirst() }

        let lower = s.lowercased()
        for prefix in ["https://", "http://"] where lower.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        let lowerHost = s.lowercased()
        for host in ["www.github.com/", "github.com/"] where lowerHost.hasPrefix(host) {
            s = String(s.dropFirst(host.count))
            // "github.com/users/name/contributions" is the graph URL; take the name after "users".
            if s.lowercased().hasPrefix("users/") { s = String(s.dropFirst(6)) }
            s = String(s.split(whereSeparator: { $0 == "/" || $0 == "?" || $0 == "#" }).first ?? "")
            break
        }

        guard isValid(s) else { throw .invalid(raw.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return s
    }

    /// GitHub's rules: 1-39 characters, letters, digits and hyphens, no leading, trailing or double hyphens.
    public static func isValid(_ s: String) -> Bool {
        guard (1...39).contains(s.count), !s.hasPrefix("-"), !s.hasSuffix("-"), !s.contains("--") else { return false }
        return s.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }
    }
}
