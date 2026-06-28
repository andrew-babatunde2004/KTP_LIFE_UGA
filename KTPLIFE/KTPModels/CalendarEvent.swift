import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?
}

#if DEBUG
extension CalendarEvent {
    static let previewSamples: [CalendarEvent] = [
        CalendarEvent(id: "1", title: "Chapter Meeting", startDate: Date(), endDate: Date(), description: "Weekly chapter meeting"),
        CalendarEvent(id: "2", title: "Professional Development Workshop", startDate: Date(), endDate: Date(), description: "Resume and interview prep with alumni"),
        CalendarEvent(id: "3", title: "Social Event", startDate: Date(), endDate: Date(), description: "End-of-semester chapter social"),
    ]
}
#endif