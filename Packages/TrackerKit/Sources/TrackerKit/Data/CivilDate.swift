import Foundation

/// A calendar day with no time or time zone attached, like GitHub's `data-date="2026-10-21"`.
///
/// Contribution days are civil dates, so all streak math works on these instead of `Date`
/// to stay correct across time zones and daylight-saving changes.
public struct CivilDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd`. Returns nil for anything else, including impossible dates.
    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), d >= 1, d <= CivilDate.daysInMonth(year: y, month: m)
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The civil date of `date` as seen in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Days since a fixed epoch (proleptic Gregorian), so adding and subtracting days is exact.
    public var dayNumber: Int {
        // Algorithm from Howard Hinnant's "days_from_civil".
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    public init(dayNumber z0: Int) {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    public func adding(days: Int) -> CivilDate {
        CivilDate(dayNumber: dayNumber + days)
    }

    public func days(until other: CivilDate) -> Int {
        other.dayNumber - dayNumber
    }

    /// 0 = Sunday ... 6 = Saturday, matching GitHub's graph rows.
    public var weekday: Int {
        let w = (dayNumber + 4) % 7 // 1970-01-01 was a Thursday
        return w >= 0 ? w : w + 7
    }

    /// Noon UTC on this day; safe to format with a UTC formatter without shifting the day.
    public var noonUTC: Date {
        Date(timeIntervalSince1970: TimeInterval(dayNumber) * 86_400 + 43_200)
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}
