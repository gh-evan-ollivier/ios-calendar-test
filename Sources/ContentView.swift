import SwiftUI

struct ContentView: View {
    let calendar: any CalendarService
    @State private var status = "Tap “Add to calendar” to get started."
    @State private var isError = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "airplane.departure")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("AF267 · ICN → CDG")
                .font(.title2.bold())
            Text(status)
                .font(.footnote)
                .foregroundStyle(isError ? .red : .secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)
            Spacer()

            button("Add to calendar", systemImage: "calendar.badge.plus", action: calendar.add)
                .buttonStyle(.borderedProminent)
            button("Update calendar event", systemImage: "pencil", action: calendar.update)
                .buttonStyle(.bordered)
            button("Cancel event", systemImage: "trash", role: .destructive, action: calendar.cancel)
                .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding()
    }

    private func button(
        _ title: String, systemImage: String, role: ButtonRole? = nil,
        action: @escaping () async throws -> String
    ) -> some View {
        Button(role: role) {
            Task {
                do { status = try await action(); isError = false }
                catch { status = error.localizedDescription; isError = true }
            }
        } label: {
            Label(title, systemImage: systemImage).frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView(calendar: MockCalendarService())
}
