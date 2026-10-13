import SwiftUI
import SwiftData

enum Status: String { case completed, skipped, failed }
enum Kind: String, CaseIterable { case binary, count, duration }
enum Freq: String, CaseIterable {
    case daily, weekdays, timesPerWeek, interval
    var label: String {
        switch self {
        case .daily: "Every day"
        case .weekdays: "Specific weekdays"
        case .timesPerWeek: "X times per week"
        case .interval: "Every N days"
        }
    }
}

let palette: [Color] = [.green, .blue, .orange, .pink, .purple, .teal, .red, .indigo]

// All properties have defaults and the relationship is optional,
// so these models are also CloudKit-ready if you add iCloud sync later.
@Model final class Habit {
    var name: String = ""
    var icon: String = "⭐️"
    var colorIdx: Int = 0
    var kindRaw: String = "binary"
    var target: Double = 1
    var unit: String = ""
    var freqRaw: String = "daily"
    var weekdays: [Int] = []      // Calendar weekday: 1=Sun ... 7=Sat
    var perWeek: Int = 3
    var interval: Int = 2
    var startDate: Date = Date()
    var archived: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Entry.habit) var entries: [Entry]? = []

    init(name: String, icon: String = "⭐️", colorIdx: Int = 0, kind: Kind = .binary,
         target: Double = 1, unit: String = "", freq: Freq = .daily,
         weekdays: [Int] = [], perWeek: Int = 3, interval: Int = 2) {
        self.name = name; self.icon = icon; self.colorIdx = colorIdx
        self.kindRaw = kind.rawValue; self.target = target; self.unit = unit
        self.freqRaw = freq.rawValue; self.weekdays = weekdays
        self.perWeek = perWeek; self.interval = interval
        self.startDate = Calendar.current.startOfDay(for: Date())
    }
    var list: [Entry] { entries ?? [] }
    var kind: Kind { Kind(rawValue: kindRaw) ?? .binary }
    var freq: Freq { Freq(rawValue: freqRaw) ?? .daily }
    var color: Color { palette[colorIdx % palette.count] }
}

@Model final class Entry {
    var day: Date = Date()
    var statusRaw: String = "completed"
    var value: Double = 0
    var note: String = ""
    var habit: Habit?
    init(day: Date, status: Status, value: Double = 0, note: String = "", habit: Habit) {
        self.day = Calendar.current.startOfDay(for: day)
        self.statusRaw = status.rawValue
        self.value = value; self.note = note; self.habit = habit
    }
    var status: Status { Status(rawValue: statusRaw) ?? .completed }
}
