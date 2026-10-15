import Foundation

@main
struct ModelChecks {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let snapshot = try JSONDecoder().decode(CanvasSnapshot.self, from: data)
        let now = Deadlines.date("2026-10-15T01:00:00Z")!
        let rows = Deadlines.rows(snapshot, now: now)
        precondition(rows.count == 9, "Expected nine grouped deadlines")
        precondition(rows.flatMap(\.assignments).count == 16, "Expected all sixteen submission links")
        precondition(rows.first?.course == "SIEN6007")
        precondition(Deadlines.label(rows.first!.due) == "Wed 21 Oct, 6 pm", "Sydney DST conversion")
        let days = AgendaDay.grouped(rows)
        precondition(days.count == 8, "Eight date headings")
        precondition(days.flatMap(\.rows).flatMap(\.assignments).count == 16, "Grouping must preserve every link")
        precondition(days.first { Deadlines.dateLabel($0.date) == "Fri 6 Nov" }?.rows.count == 2, "Keep both courses on the same day")
        let group = rows.first { $0.course == "FINC6017" }!
        precondition(group.assignments.count == 7)
        precondition(Deadlines.label(group.due) == "Fri 6 Nov, 11:59 pm")
        precondition(Deadlines.label(Deadlines.date("2026-09-25T13:59:59Z")!) == "Fri 25 Sep, 11:59 pm", "Sydney standard-time conversion")
        let admin = CanvasCourse(id: 1, name: "Taking BYOD exams", course_code: "BYOD_TEST_SUPPORT_SITE", assignments: snapshot.courses[0].assignments)
        let augmented = CanvasSnapshot(checkedAt: snapshot.checkedAt, courses: snapshot.courses + [admin])
        precondition(Deadlines.rows(augmented, now: now).count == 9, "Admin hub must be excluded")
        let afterSemester = Deadlines.date("2026-12-21T01:00:00Z")!
        precondition(Deadlines.rows(snapshot, now: afterSemester).isEmpty, "Past deadlines must age out")
        print("PASS: 9 deadlines, 16 links, 7 group submissions, AEST/AEDT, admin exclusion, and past-deadline filtering")
    }
}
