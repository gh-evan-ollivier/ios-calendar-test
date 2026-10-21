import CoreLocation
import EventKit
import Foundation

/// The flight from "Flight AF267 to Paris.ics".
struct FlightEvent {
    var title = "Vol AF267 de Séoul (ICN) à Paris (CDG)"
    var location = "Aéroport international dIncheon (ICN), Séoul"
    var latitude = 37.449200
    var longitude = 126.450950
    var url = URL(string: "https://airfrance.com/")
    var notes = """
        Numéro de réservation : Z837OM

        Départ : Aéroport international dIncheon (ICN) - 29/10/2026 13:20 (Asia/Seoul)

        Arrivée : Aéroport Paris–Charles de Gaulle (CDG) - 29/10/2026 19:45 (Europe/Paris)

        Voir la réservation sur AirFrance:  https://airfrance.com/
        
        """
    var timeZone = TimeZone(identifier: "Asia/Seoul")!
    var start = Self.date(2026, 10, 29, 13, 20, "Asia/Seoul")
    var end = Self.date(2026, 10, 29, 19, 45, "Europe/Paris")

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ tz: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    case noEvent

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access was denied. Enable it in Settings."
        case .noEvent: "No event to update or cancel. Add one first."
        }
    }
}

@MainActor
protocol CalendarService: AnyObject {
    var hasEvent: Bool { get }
    func add() async throws -> String
    func update() async throws -> String
    func cancel() async throws -> String
}

@MainActor
@Observable
final class EventKitCalendarService: CalendarService {
    private let store = EKEventStore()
    private let flight = FlightEvent()
    private let key = "flightEventIdentifier"

    private var eventIdentifier: String? {
        didSet { UserDefaults.standard.set(eventIdentifier, forKey: key) }
    }

    init() { eventIdentifier = UserDefaults.standard.string(forKey: key) }

    var hasEvent: Bool { existingEvent() != nil }

    private func requestAccess() async throws {
        guard try await store.requestFullAccessToEvents() else { throw CalendarError.accessDenied }
    }

    private func existingEvent() -> EKEvent? {
        eventIdentifier.flatMap { store.event(withIdentifier: $0) }
    }

    func add() async throws -> String {
        try await requestAccess()
        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents
        event.title = flight.title
                event.notes = flight.notes
        event.url = flight.url
        event.timeZone = flight.timeZone
        let place = EKStructuredLocation(title: flight.location)
        place.geoLocation = CLLocation(latitude: flight.latitude, longitude: flight.longitude)
        place.radius = 500
        event.structuredLocation = place
        event.startDate = flight.start
        event.endDate = flight.end
        event.addAlarm(EKAlarm(relativeOffset: -3 * 3600))
        try store.save(event, span: .thisEvent)
        eventIdentifier = event.eventIdentifier
        return "Added “\(flight.title)”."
    }

    func update() async throws -> String {
        try await requestAccess()
        guard let event = existingEvent() else { throw CalendarError.noEvent }
        event.title = "\(flight.title) (delayed 1h)"
        event.startDate = event.startDate.addingTimeInterval(3600)
        event.endDate = event.endDate.addingTimeInterval(3600)
        try store.save(event, span: .thisEvent)
        return "Event moved 1 hour later."
    }

    func cancel() async throws -> String {
        try await requestAccess()
        guard let event = existingEvent() else { throw CalendarError.noEvent }
        try store.remove(event, span: .thisEvent)
        eventIdentifier = nil
        return "Event cancelled."
    }
}

/// In-memory stand-in so previews never touch the real calendar or prompt for access.
@MainActor
@Observable
final class MockCalendarService: CalendarService {
    private(set) var hasEvent = false
    func add() async throws -> String { hasEvent = true; return "Added (mock)." }
    func update() async throws -> String {
        guard hasEvent else { throw CalendarError.noEvent }
        return "Updated (mock)."
    }
    func cancel() async throws -> String {
        guard hasEvent else { throw CalendarError.noEvent }
        hasEvent = false
        return "Cancelled (mock)."
    }
}
