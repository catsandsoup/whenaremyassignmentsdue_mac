import Foundation

struct CanvasDeadlineSubmission: Codable {
    let workflow_state: String?
    let submitted_at: String?
    let redo_request: Bool?

    var isSubmitted: Bool {
        // A grade alone can be a missing-work zero. Reassigned work still needs action.
        guard redo_request != true, workflow_state != "unsubmitted" else { return false }
        return submitted_at.flatMap(Deadlines.date) != nil
            || workflow_state == "submitted" || workflow_state == "pending_review"
    }
}

struct CanvasAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let html_url: String?
    let published: Bool?
    var submission: CanvasDeadlineSubmission? = nil
    var isSubmitted: Bool { submission?.isSubmitted == true }
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Assessment 2: Progress presentations") {
            return trimmed.replacingOccurrences(of: "^.*; ([0-9]+) of [0-9]+.*$", with: "Progress Presentation $1", options: .regularExpression)
        }
        if trimmed.hasPrefix("Assessment 3: Financial metrics") {
            return "Assessment 3: Financial Metrics / Startup Pitch"
        }
        return trimmed
    }
}

struct CanvasCourse: Codable, Identifiable {
    let id: Int
    let name: String
    let course_code: String
    let assignments: [CanvasAssignment]

    var academicCode: String? {
        course_code.range(of: "^[A-Z]{4}[0-9]{4}\\b", options: .regularExpression)
            .map { String(course_code[$0]) }
    }
}

struct CanvasSnapshot: Codable {
    let checkedAt: String
    let courses: [CanvasCourse]
}

struct DeadlineRow: Identifiable {
    let id: String
    let course: String
    let due: Date
    let assignments: [CanvasAssignment]
    var isSubmitted: Bool { !assignments.isEmpty && assignments.allSatisfy(\.isSubmitted) }
    var submissionLabel: String? {
        let submitted = assignments.filter(\.isSubmitted).count
        guard submitted > 0 else { return nil }
        return isSubmitted ? "Submitted" : "\(submitted) of \(assignments.count) submitted"
    }
}

enum Deadlines {
    static let zone = TimeZone(identifier: "Australia/Sydney")!
    static func date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let value = formatter.date(from: string) { return value }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: string)
    }

    static func rows(_ snapshot: CanvasSnapshot?, now: Date = Date()) -> [DeadlineRow] {
        guard let snapshot else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: now)
        var result: [DeadlineRow] = []
        for course in snapshot.courses {
            guard let code = course.academicCode else { continue }
            let dated = course.assignments.compactMap { assignment -> (CanvasAssignment, Date)? in
                guard assignment.published != false,
                      let raw = assignment.due_at,
                      let due = date(raw), due >= start else { return nil }
                return (assignment, due)
            }
            let groups = Dictionary(grouping: dated) { Int($0.1.timeIntervalSince1970 / 60) }
            for (minute, items) in groups {
                result.append(DeadlineRow(id: "\(course.id)-\(minute)", course: code,
                    due: items.map(\.1).min()!,
                    assignments: items.map(\.0).sorted { $0.id < $1.id }))
            }
        }
        return result.sorted { $0.due == $1.due ? $0.course < $1.course : $0.due < $1.due }
    }

    static func visibleRows(_ rows: [DeadlineRow], hideSubmitted: Bool) -> [DeadlineRow] {
        guard hideSubmitted else { return rows }
        return rows.compactMap { row in
            let remaining = row.assignments.filter { !$0.isSubmitted }
            guard !remaining.isEmpty else { return nil }
            return DeadlineRow(id: row.id, course: row.course, due: row.due, assignments: remaining)
        }
    }

    static func label(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = zone
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return formatter.string(from: date).replacingOccurrences(of: ":00", with: "").lowercasedAMPM
    }

    static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = zone
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }
    static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = zone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).replacingOccurrences(of: ":00", with: "").lowercasedAMPM
    }
    static func daysUntil(_ due: Date, now: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
    }
    static func urgencyLabel(_ due: Date, now: Date = Date()) -> String {
        if due < now { return "Overdue" }
        switch daysUntil(due, now: now) {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case let days: return "In \(days) days"
        }
    }
}

extension String {
    var lowercasedAMPM: String {
        replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
    }
}


struct AgendaDay: Identifiable {
    let date: Date
    let rows: [DeadlineRow]
    var id: Date { date }
    static func grouped(_ rows: [DeadlineRow]) -> [AgendaDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Deadlines.zone
        return Dictionary(grouping: rows) { calendar.startOfDay(for: $0.due) }
            .map { AgendaDay(date: $0.key, rows: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

// Uses calendar days in Sydney, independent of the Mac's time zone and network availability.
enum MenuBarDeadline {
    static func text(rows: [DeadlineRow], now: Date, countdownOnly: Bool = false) -> String? {
        guard let next = rows.filter({ $0.due >= now && !$0.isSubmitted }).min(by: {
            $0.due == $1.due ? $0.course < $1.course : $0.due < $1.due
        }) else { return nil }
        let days = Deadlines.daysUntil(next.due, now: now)
        let countdown = days == 0 ? "due today" : "in \(days)d"
        return countdownOnly ? (days == 0 ? "Due today" : "In \(days)d") : next.course + " " + countdown
    }
}
