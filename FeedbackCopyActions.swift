import SwiftUI
import AppKit
import Accessibility

enum FeedbackClipboard {
    static func copy(_ text: String, confirmation: String) -> String {
        NSPasteboard.general.clearContents()
        let success = NSPasteboard.general.setString(text, forType: .string)
        let message = success ? confirmation : "Could not copy. Try again."
        AccessibilityNotification.Announcement(message).post()
        return message
    }
}

// Named full-copy actions use the platform pasteboard; range selection and Cmd-C stay native.
struct FeedbackCopyActions: View {
    let item: FeedbackItem
    var copied: (String) -> Void = { _ in }
    var body: some View {
        Button("Copy Feedback", systemImage: "doc.on.doc") { copy(FeedbackExport.feedback(item), notice: "Feedback copied") }
        Button("Copy Rubric", systemImage: "list.clipboard") { copy(FeedbackExport.rubric(item), notice: "Rubric copied") }
            .disabled(!FeedbackExport.hasRubric(item))
    }
    private func copy(_ text: String, notice: String) {
        copied(FeedbackClipboard.copy(text, confirmation: notice))
    }
}
