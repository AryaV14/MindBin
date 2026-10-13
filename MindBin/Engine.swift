import Foundation

let cal = Calendar.current
extension Date {
    var day: Date { cal.startOfDay(for: self) }
    func adding(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: self)! }
    var weekStart: Date { cal.dateInterval(of: .weekOfYear, for: self)!.start }
}

struct Stats {
    var current = 0, longest = 0, done = 0, missed = 0
    var unit = "days"
    var rate: Double { done + missed == 0 ? 0 : Double(done) / Double(done + missed) }
}

extension Habit {
    func entry(on d: Date) -> Entry? { list.first { $0.day == d.day } }
    func status(on d: Date) -> Status? { entry(on: d)?.status }

    /// Fixed-schedule check (not used for "X per week", which is flexible).
    func isScheduled(_ d: Date) -> Bool {
        let d = d.day
        guard d >= startDate.day, !archived else { return false }
        switch freq {
        case .daily: return true
        case .weekdays: return weekdays.contains(cal.component(.weekday, from: d))
        case .timesPerWeek: return false
        case .interval:
            let n = cal.dateComponents([.day], from: startDate.day, to: d).day ?? 0
            return n % max(interval, 1) == 0
        }
    }

    func doneThisWeek(_ d: Date) -> Int {
        let s = d.weekStart, e = s.adding(7)
        return list.filter { $0.status == .completed && $0.day >= s && $0.day < e }.count
    }

    /// Should this habit appear on the Today list?
    func isDue(_ d: Date) -> Bool {
        if entry(on: d) != nil { return true }
        if freq == .timesPerWeek { return d.day >= startDate.day && doneThisWeek(d) < perWeek }
        return isScheduled(d)
    }

    /// Skipped = neutral (keeps streak, doesn't count). Pending today = neutral.
    func stats(today: Date = Date().day) -> Stats {
        var s = Stats(); var run = 0
        if freq == .timesPerWeek {
            s.unit = "weeks"
            var w = startDate.weekStart
            while w <= today {
                let n = doneThisWeek(w)
                if n >= perWeek { run += 1; s.done += 1; s.longest = max(s.longest, run) }
                else if w != today.weekStart { run = 0; s.missed += 1 }
                w = w.adding(7)
            }
        } else {
            var d = startDate.day
            while d <= today {
                if isScheduled(d) {
                    switch status(on: d) {
                    case .completed: run += 1; s.done += 1; s.longest = max(s.longest, run)
                    case .skipped: break
                    default: if d != today { run = 0; s.missed += 1 }
                    }
                }
                d = d.adding(1)
            }
        }
        s.current = run
        return s
    }
}

enum Overall {
    /// Day progress over fixed-schedule habits; skipped habits are excluded.
    static func progress(_ hs: [Habit], _ d: Date) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for h in hs where h.isScheduled(d) {
            switch h.status(on: d) {
            case .skipped: continue
            case .completed: done += 1; total += 1
            default: total += 1
            }
        }
        return (done, total)
    }

    /// A "perfect day" = every scheduled habit completed. Overall streak counts perfect days.
    static func stats(_ hs: [Habit]) -> Stats {
        var s = Stats(); var run = 0
        guard let first = hs.map({ $0.startDate.day }).min() else { return s }
        let today = Date().day; var d = first
        while d <= today {
            let p = progress(hs, d)
            if p.total > 0 {
                if p.done == p.total { run += 1; s.done += 1; s.longest = max(s.longest, run) }
                else if d != today { run = 0; s.missed += 1 }
            }
            d = d.adding(1)
        }
        s.current = run
        return s
    }
}
