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
        print("PASS: identity-based selection replaces PDF/comment data, search clears hidden selection, released zero vs unposted mark, rubric sources")
    }
}
