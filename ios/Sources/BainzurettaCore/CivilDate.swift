import Foundation

/// `data` is a civil local timestamp, even when Strava labels it Z. Never shift it to the device timezone.
public struct CivilDate: Equatable, Comparable, Sendable {
    public let year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, millisecond: Int
    public let dayNumber: Int
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; c.locale = Locale(identifier: "en_US_POSIX"); return c
    }
    public init(_ text: String) throws {
        let regex = try NSRegularExpression(pattern: #"^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?(?:Z|[+-]\d{2}:\d{2})?)?$"#)
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.range.length == ns.length else { throw ArchiveError.invalid("data ISO") }
        func part(_ i: Int) -> String { m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i)) }
        year = Int(part(1))!; month = Int(part(2))!; day = Int(part(3))!
        hour = Int(part(4)) ?? 0; minute = Int(part(5)) ?? 0; second = Int(part(6)) ?? 0
        millisecond = Int((part(7) + "000").prefix(3)) ?? 0
        guard year >= 1, (1...12).contains(month), (1...31).contains(day), hour <= 23, minute <= 59, second <= 59,
              let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self.calendar.component(.month, from: date) == month, Self.calendar.component(.day, from: date) == day else { throw ArchiveError.invalid("data impossibile") }
        // Validate timezone offsets too; their values do not alter civil grouping.
        if let range = text.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) {
            let offset = text[range].dropFirst().split(separator: ":").compactMap { Int($0) }
            guard offset[0] <= 23 && offset[1] <= 59 else { throw ArchiveError.invalid("fuso orario") }
        }
        dayNumber = Int(floor(date.timeIntervalSince1970 / 86400))
    }
    public static func < (a: Self, b: Self) -> Bool { a.sortTime < b.sortTime }
    public var sortTime: Double { Double(dayNumber * 86400 + hour * 3600 + minute * 60 + second) + Double(millisecond) / 1000 }
    public var dayOfYear: Int { dayNumber - Self.dayNumber(year: year, month: 1, day: 1) + 1 }
    public var monday: Int { dayNumber - ((dayNumber + 3) % 7) }
    public var absoluteWeek: Int { Int(floor(Double(monday - 4) / 7)) }
    public var isoDay: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public var isoMonth: String { String(format: "%04d-%02d", year, month) }
    public var display: String { String(format: "%02d/%02d/%04d", day, month, year) }
    public var weekday: Int { ((dayNumber + 4) % 7 + 7) % 7 }
    public static func daysInYear(_ y: Int) -> Int { y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) ? 366 : 365 }
    public static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        Int(floor(calendar.date(from: DateComponents(year: year, month: month, day: day))!.timeIntervalSince1970 / 86400))
    }
    public static func fromDay(_ number: Int) -> CivilDate {
        let c = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(number) * 86400))
        return try! CivilDate(String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!))
    }
    public static func today(_ date: Date = Date(), zone: TimeZone = .current) -> CivilDate {
        var c = calendar; c.timeZone = zone
        let p = c.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return try! CivilDate(String(format: "%04d-%02d-%02dT%02d:%02d:%02d", p.year!, p.month!, p.day!, p.hour!, p.minute!, p.second!))
    }
}

public enum Display {
    public static func number(_ value: Double, _ decimals: Int = 1) -> String {
        guard value.isFinite, var decimal = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) else { return "—" }
        var rounded = Decimal(); NSDecimalRound(&rounded, &decimal, decimals, .plain)
        let raw = NSDecimalNumber(decimal: rounded).stringValue
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        let whole = String(parts[0]), negative = whole.hasPrefix("-")
        let digits = negative ? String(whole.dropFirst()) : whole
        let grouped = digits.enumerated().map { index, char in
            (digits.count >= 5 && index > 0 && (digits.count - index) % 3 == 0 ? "." : "") + String(char)
        }.joined()
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        return (negative ? "-" : "") + grouped + (decimals > 0 ? "," + String((fraction + String(repeating: "0", count: decimals)).prefix(decimals)) : "")
    }
    public static func fixed(_ value: Double, _ decimals: Int) -> String { String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, value) }
    public static func time(_ hours: Double) -> String {
        guard hours.isFinite, hours >= 0, hours * 3600 < Double(Int64.max) else { return "—" }
        let s = Int64(floor(hours * 3600 + 0.5))
        return String(format: "%lld:%02lld:%02lld", s / 3600, s % 3600 / 60, s % 60)
    }
    public static func hours(_ hours: Double) -> String {
        let m = floor(hours * 60 + 0.5)
        return "\(Int(m / 60)) h \(String(format: "%02d", Int(m.truncatingRemainder(dividingBy: 60)))) m"
    }
    public static let months = ["Gennaio","Febbraio","Marzo","Aprile","Maggio","Giugno","Luglio","Agosto","Settembre","Ottobre","Novembre","Dicembre"]
    public static let weekdays = ["Domenica","Lunedì","Martedì","Mercoledì","Giovedì","Venerdì","Sabato"]
}
