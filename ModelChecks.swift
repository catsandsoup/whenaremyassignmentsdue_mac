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
        precondition(MenuBarDeadline.text(rows: rows, now: now) == "SIEN6007 in 6d")
        precondition(MenuBarDeadline.text(rows: rows, now: now, countdownOnly: true) == "In 6d")
        let dueDay = Deadlines.date("2026-10-21T00:00:00Z")!
        precondition(MenuBarDeadline.text(rows: rows, now: dueDay) == "SIEN6007 due today")
        let justAfter = rows.first!.due.addingTimeInterval(1)
        precondition(MenuBarDeadline.text(rows: rows, now: justAfter) == "FINC6001 in 2d", "Advance after exact deadline")
        precondition(MenuBarDeadline.text(rows: rows, now: afterSemester) == nil, "No negative countdowns")
        precondition(MenuBarDeadline.text(rows: [], now: now) == nil)
        func assignment(_ submission: String?) throws -> CanvasAssignment {
            let extra = submission.map { ",\"submission\":" + $0 } ?? ""
            return try JSONDecoder().decode(CanvasAssignment.self, from: Data(("{\"id\":1,\"name\":\"Report\"" + extra + "}").utf8))
        }
        let submitted = try assignment(#"{"workflow_state":"submitted","submitted_at":"2026-10-15T01:00:00Z"}"#)
        precondition(submitted.isSubmitted)
        let pending = try assignment(#"{"workflow_state":"pending_review"}"#)
        precondition(pending.isSubmitted)
        let graded = try assignment(#"{"workflow_state":"graded","submitted_at":"2026-10-15T01:00:00Z"}"#)
        precondition(graded.isSubmitted)
        for payload in [nil, "null", #"{"workflow_state":"unsubmitted"}"#,
                        #"{"workflow_state":"graded","score":0}"#,
                        #"{"workflow_state":"submitted","redo_request":true}"#,
                        #"{"workflow_state":"unsubmitted","submitted_at":"2026-10-15T01:00:00Z"}"#] {
            let item = try assignment(payload)
            precondition(!item.isSubmitted, "Unknown, unsubmitted, grade-only and reassigned work must remain actionable")
        }
        let unsent = try assignment(nil)
        let mixed = DeadlineRow(id: "mixed", course: "TEST1001", due: now, assignments: [submitted, unsent])
        precondition(!mixed.isSubmitted && mixed.submissionLabel == "1 of 2 submitted")
        let complete = DeadlineRow(id: "done", course: "TEST1001", due: now, assignments: [submitted, submitted])
        precondition(complete.isSubmitted && complete.submissionLabel == "Submitted")
        let nextUnsubmitted = DeadlineRow(id: "next", course: "NEXT1001", due: now.addingTimeInterval(86400), assignments: [unsent])
        precondition(MenuBarDeadline.text(rows: [complete, nextUnsubmitted], now: now) == "NEXT1001 in 1d", "Skip fully submitted deadlines")
        precondition(MenuBarDeadline.text(rows: [complete, nextUnsubmitted], now: now, countdownOnly: true) == "In 1d", "Compact countdown must also skip submitted work")
        precondition(MenuBarDeadline.text(rows: [mixed, nextUnsubmitted], now: now) == "TEST1001 due today", "Partial groups still need action")
        precondition(MenuBarDeadline.text(rows: [complete], now: now) == nil, "No countdown when everything is submitted")
        precondition(MenuBarDeadline.text(rows: [complete], now: now, countdownOnly: true) == nil)
        precondition(MenuBarDeadline.text(rows: [complete, nextUnsubmitted], now: now.addingTimeInterval(86401)) == nil, "Past work must still age out")
        print("PASS: countdown skips submitted work in both modes, retains partial groups and clears when all work is submitted")
        let originalRows = [complete, mixed, nextUnsubmitted]
        let outstandingRows = Deadlines.visibleRows(originalRows, hideSubmitted: true)
        precondition(outstandingRows.map(\.id) == ["mixed", "next"], "Remove fully submitted groups without reordering deadlines")
        precondition(outstandingRows.first?.assignments.count == 1 && outstandingRows.first?.assignments.first?.isSubmitted == false, "Hide submitted members of a mixed group")
        precondition(outstandingRows.first?.due == mixed.due && outstandingRows.first?.course == mixed.course, "Preserve date and course context")
        precondition(Deadlines.visibleRows(originalRows, hideSubmitted: false).map { $0.assignments.count } == [2, 2, 1], "Turning the filter off restores all items without changing the source")
        precondition(Deadlines.visibleRows([complete], hideSubmitted: true).isEmpty)
        precondition(Deadlines.visibleRows([], hideSubmitted: true).isEmpty)
        precondition(AgendaDay.grouped(Deadlines.visibleRows([complete], hideSubmitted: true)).isEmpty, "No orphan date headings")
        print("PASS: hide submitted removes completed items and empty groups, retains unfinished group members and restores all source rows")
        let roundTrip = try JSONDecoder().decode(CanvasAssignment.self, from: JSONEncoder().encode(submitted))
        precondition(roundTrip.isSubmitted, "Submission status must survive offline caching")
        print("PASS: submitted deadline status, pending review, graded submissions, missing-work zeros, reassignment, mixed groups and offline status")
        print("PASS: next-deadline menu label, calendar days, due today, automatic progression and no future deadlines")
        print("PASS: 9 deadlines, 16 links, 7 group submissions, AEST/AEDT, admin exclusion, and past-deadline filtering")
    }
}
