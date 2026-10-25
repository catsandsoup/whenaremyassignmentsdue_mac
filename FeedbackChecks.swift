import Foundation
@main struct FeedbackChecks {
    static func main() throws {
        let items = FeedbackDesignFixture.items
        var state = FeedbackSelection()
        state.select(items[0].id, in: items)
        precondition(state.item(in: items)?.id == items[0].id)
        state.select(items[3].id, in: items)
        let selected = state.item(in: items)!
        precondition(selected.attachments.isEmpty, "Old PDF must not leak into new selection")
        precondition(selected.title == "AI Feedback Task 1")
        state.search = "no matching title"
        state.reconcile(in: items)
        precondition(state.item(in: items) == nil, "Filtered-out selection must clear reader")
        state.search = "sien6007"
        precondition(state.visible(items).allSatisfy { $0.course == "SIEN6007" })
        var zero = selected; zero.score = 0; zero.grade = "0"
        precondition(zero.markLabel == "0/5", "Posted zero is not unavailable")
        zero.postedAt = nil
        precondition(zero.markLabel == nil, "Unposted grade stays unavailable")
        precondition(items[0].rubricState == .document)
        precondition(items.last!.rubricState == .criteria)
        precondition(items[0].prioritizesFeedback, "A result PDF must appear before original teaching materials")
        var upcoming = items.last!
        upcoming.comments = []; upcoming.assessments = [:]; upcoming.postedAt = nil
        upcoming.workflowState = "unsubmitted"
        precondition(!upcoming.prioritizesFeedback, "Criteria alone must keep materials first")
        precondition(upcoming.navigationSubtitle == "Not submitted")
        upcoming.workflowState = "submitted"
        precondition(upcoming.navigationSubtitle == "Submitted")
        upcoming.workflowState = "graded"
        precondition(upcoming.navigationSubtitle == "Result not released", "Do not imply a missing numeric mark means ungraded")
        upcoming.workflowState = "unknown"
        precondition(upcoming.navigationSubtitle.isEmpty, "Unknown state should not repeat a misleading mark warning")
        upcoming.sourceAssignment = Data(#"{"due_at":"2099-10-25T13:00:00Z"}"#.utf8)
        precondition(AssignmentScope.upcoming.includes(upcoming))
        upcoming.sourceAssignment = Data(#"{"due_at":"2000-10-25T13:00:00Z"}"#.utf8)
        precondition(!AssignmentScope.upcoming.includes(upcoming))
        precondition(AssignmentScope.feedback.includes(items[0]))
        precondition(AssignmentScope.all.includes(upcoming))
        print("PASS: identity-based selection replaces PDF/comment data, search clears hidden selection, released zero vs unposted mark, rubric sources")
    }
}
