import SwiftUI

@main
struct CalendarTestApp: App {
    @State private var calendar = EventKitCalendarService()

    var body: some Scene {
        WindowGroup {
            ContentView(calendar: calendar)
        }
    }
}
