import SwiftUI
import SwiftData

struct StatCard: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(icon + " " + title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 12-week heatmap. value: nil = no data, 0 = missed, 0...1 = intensity.
struct Heatmap: View {
    let tint: Color
    let value: (Date) -> Double?
    var body: some View {
        let today = Date().day
        let start = today.weekStart.adding(-77)
        LazyHGrid(rows: Array(repeating: GridItem(.fixed(16), spacing: 3), count: 7), spacing: 3) {
            ForEach(0..<84, id: \.self) { i in
                let d = start.adding(i)
                let v: Double? = d > today ? nil : value(d)
                RoundedRectangle(cornerRadius: 3).fill(color(v)).frame(width: 16, height: 16)
            }
        }
        .frame(height: 7 * 16 + 6 * 3)
    }
    func color(_ v: Double?) -> Color {
        guard let v else { return Color.gray.opacity(0.12) }
        if v == 0 { return Color.red.opacity(0.25) }
        return tint.opacity(0.3 + 0.7 * v)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "checkmark.circle") }
            HabitsView().tabItem { Label("Habits", systemImage: "list.bullet") }
            OverallView().tabItem { Label("Streaks", systemImage: "flame") }
        }
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.name) private var habits: [Habit]
    var body: some View {
        let today = Date().day
        let due = habits.filter { $0.isDue(today) }
        let done = due.filter { $0.status(on: today) == .completed }.count
        NavigationStack {
            List {
                Section {
                    ProgressView(value: due.isEmpty ? 0 : Double(done) / Double(due.count))
                    Text("\(done) / \(due.count) completed").font(.headline)
                }
                Section("Today") {
                    ForEach(due) { h in
                        HStack {
                            Text(h.icon)
                            VStack(alignment: .leading) {
                                Text(h.name)
                                if h.freq == .timesPerWeek {
                                    Text("\(h.doneThisWeek(today))/\(h.perWeek) this week")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("🔥\(h.stats().current)").font(.caption)
                            Image(systemName: icon(h.status(on: today)))
                                .foregroundStyle(h.color).font(.title2)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { set(h, h.status(on: today) == .completed ? nil : .completed) }
                        .contextMenu {
                            Button("✓ Complete") { set(h, .completed) }
                            Button("⏭ Skip") { set(h, .skipped) }
                            Button("✕ Failed") { set(h, .failed) }
                            Button("Clear") { set(h, nil) }
                        }
                    }
                }
            }
            .navigationTitle(today.formatted(.dateTime.weekday(.wide).month().day()))
        }
    }
    func icon(_ s: Status?) -> String {
        switch s {
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.circle.fill"
        case .failed: "xmark.circle.fill"
        case nil: "circle"
        }
    }
    func set(_ h: Habit, _ s: Status?) {
        let today = Date().day
        if let e = h.entry(on: today) { ctx.delete(e) }
        if let s { ctx.insert(Entry(day: today, status: s, value: s == .completed ? h.target : 0, habit: h)) }
    }
}

struct HabitsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Habit.name) private var habits: [Habit]
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { h in
                    NavigationLink(destination: HabitDetail(habit: h)) {
                        HStack {
                            Text(h.icon); Text(h.name)
                            if h.archived { Text("archived").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text("🔥\(h.stats().current)")
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { ctx.delete(h) }
                        Button(h.archived ? "Restore" : "Archive") { h.archived.toggle() }.tint(.orange)
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { AddHabitView() }
        }
    }
}

/// PER-HABIT streak dashboard
struct HabitDetail: View {
    let habit: Habit
    var body: some View {
        let s = habit.stats()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Current streak", value: "\(s.current) \(s.unit)", icon: "🔥")
                    StatCard(title: "Best streak", value: "\(s.longest) \(s.unit)", icon: "🏆")
                    StatCard(title: "Completion rate", value: "\(Int(s.rate * 100))%", icon: "📈")
                    StatCard(title: "Total completions",
                             value: "\(habit.list.filter { $0.status == .completed }.count)", icon: "✅")
                    StatCard(title: "Skipped",
                             value: "\(habit.list.filter { $0.status == .skipped }.count)", icon: "⏭")
                    StatCard(title: "Missed / failed", value: "\(s.missed)", icon: "✕")
                }
                Text("Last 12 weeks").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    Heatmap(tint: habit.color) { d in
                        if let st = habit.status(on: d) {
                            if st == .completed { return 1.0 }
                            if st == .failed { return 0.0 }
                            return nil
                        }
                        return habit.isScheduled(d) ? 0.0 : nil
                    }
                }
                Text("Skipped days don't break the streak. Unscheduled days are ignored.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle("\(habit.icon) \(habit.name)")
    }
}

/// OVERALL streak dashboard
struct OverallView: View {
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.name) private var habits: [Habit]
    var body: some View {
        let s = Overall.stats(habits)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Perfect-day streak", value: "\(s.current) days", icon: "🔥")
                        StatCard(title: "Best streak", value: "\(s.longest) days", icon: "🏆")
                        StatCard(title: "Perfect days", value: "\(s.done)", icon: "⭐️")
                        StatCard(title: "Perfect-day rate", value: "\(Int(s.rate * 100))%", icon: "📈")
                    }
                    Text("Daily completion · last 12 weeks").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Heatmap(tint: .green) { d in
                            let p = Overall.progress(habits, d)
                            return p.total == 0 ? nil : Double(p.done) / Double(p.total)
                        }
                    }
                    Text("Habit streaks").font(.headline)
                    ForEach(habits.sorted { $0.stats().current > $1.stats().current }) { h in
                        let hs = h.stats()
                        HStack {
                            Text(h.icon); Text(h.name); Spacer()
                            Text("🔥 \(hs.current) · 🏆 \(hs.longest) \(hs.unit)").font(.subheadline)
                        }
                        Divider()
                    }
                }.padding()
            }
            .navigationTitle("Streaks")
        }
    }
}

struct AddHabitView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "💧"
    @State private var color = 0
    @State private var kind = Kind.binary
    @State private var target = 1.0
    @State private var unit = ""
    @State private var freq = Freq.daily
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var perWeek = 3
    @State private var interval = 2
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Emoji icon", text: $icon)
                Picker("Color", selection: $color) {
                    ForEach(0..<palette.count, id: \.self) { Text("●").foregroundStyle(palette[$0]).tag($0) }
                }
                Picker("Type", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                if kind != .binary {
                    HStack { Text("Target"); TextField("", value: $target, format: .number); TextField("unit", text: $unit) }
                }
                Picker("Frequency", selection: $freq) { ForEach(Freq.allCases, id: \.self) { Text($0.label).tag($0) } }
                switch freq {
                case .weekdays:
                    HStack {
                        ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { i, l in
                            Button(l) { if days.contains(i + 1) { days.remove(i + 1) } else { days.insert(i + 1) } }
                                .buttonStyle(.borderedProminent).tint(days.contains(i + 1) ? .accentColor : .gray)
                        }
                    }
                case .timesPerWeek: Stepper("\(perWeek) times per week", value: $perWeek, in: 1...7)
                case .interval: Stepper("Every \(interval) days", value: $interval, in: 2...60)
                case .daily: EmptyView()
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ctx.insert(Habit(name: name, icon: icon, colorIdx: color, kind: kind, target: target,
                                         unit: unit, freq: freq, weekdays: Array(days), perWeek: perWeek, interval: interval))
                        dismiss()
                    }.disabled(name.isEmpty)
                }
            }
        }
    }
}
