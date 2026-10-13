import SwiftUI
import SwiftData

@main
struct MindBinApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Habit.self, Entry.self])
    }
}
