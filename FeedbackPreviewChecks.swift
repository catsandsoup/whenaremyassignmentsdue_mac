import Foundation

@main struct FeedbackPreviewChecks {
    @MainActor static func main() async {
        var item = FeedbackDesignFixture.items[0]
        var submitted = item.attachments[0]; submitted.id = 800; submitted.name = "My submission.docx"
        item.submissionFiles = [submitted, item.attachments[0]]
        precondition(item.previewFiles.map(\.id) == [1, 800], "Preview must include feedback first, current submission files second, deduplicated by file identity")
        let preview = FeedbackPreview()
        let first = URL(fileURLWithPath: "/tmp/first.pdf"), second = URL(fileURLWithPath: "/tmp/second.docx")
        preview.show(item.previewFiles) { $0.id == 1 ? first : second }
        while preview.loading { await Task.yield() }
        precondition(preview.urls == [first, second] && preview.selection == first)
        preview.selection = nil
        preview.show([]) { _ in preconditionFailure("No file should be fetched") }
        precondition(preview.selection == nil && !preview.message.isEmpty)
        preview.show(item.previewFiles) { $0.id == 1 ? nil : second }
        while preview.loading { await Task.yield() }
        precondition(preview.urls == [second] && !preview.message.isEmpty, "A failed file must not hide available documents")

        var release: CheckedContinuation<URL?, Never>?
        preview.show(item.previewFiles) { _ in await withCheckedContinuation { release = $0 } }
        while release == nil { await Task.yield() }
        preview.cancel() // selection changes / window closes while a fetch finishes
        release?.resume(returning: first)
        for _ in 0..<10 { await Task.yield() }
        precondition(preview.selection == nil && preview.urls.isEmpty && !preview.loading, "A late result must not reopen the previous assessment")
        var finishDownload: CheckedContinuation<URL?, Never>?
        preview.show(item.previewFiles, cached: { $0.id == 1 ? first : nil }) { _ in
            await withCheckedContinuation { finishDownload = $0 }
        }
        precondition(preview.selection == first, "Cached feedback must open immediately without waiting for another document's download")
        while finishDownload == nil { await Task.yield() }
        finishDownload?.resume(returning: second)
        while preview.loading { await Task.yield() }
        precondition(preview.urls == [first, second])
        print("PASS: assessment Quick Look collection includes feedback/current submissions, partial failure recovery and cancelled selection isolation")
    }
}
