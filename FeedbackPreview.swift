import Foundation
import Combine

// One Quick Look session per reader window. No global key monitor or custom preview UI.
@MainActor final class FeedbackPreview: ObservableObject {
    @Published var selection: URL?
    @Published private(set) var urls: [URL] = []
    @Published private(set) var loading = false
    @Published private(set) var message = ""
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func show(_ files: [FeedbackAttachment], cached: (FeedbackAttachment) -> URL? = { _ in nil }, obtain: @escaping (FeedbackAttachment) async -> URL?) {
        guard !loading else { return }
        cancel()
        guard !files.isEmpty else { message = "No attached documents are available for this assessment."; return }
        let request = generation
        let saved = Dictionary(files.compactMap { file in cached(file).map { (file.id, $0) } }, uniquingKeysWith: { first, _ in first })
        var initial: [URL] = []
        for file in files {
            if let url = saved[file.id], !initial.contains(url) { initial.append(url) }
        }
        urls = initial; selection = initial.first
        loading = true
        task = Task {
            var available = initial
            var succeeded = saved.count
            for file in files {
                guard !Task.isCancelled else { return }
                guard saved[file.id] == nil else { continue }
                if let url = await obtain(file) {
                    guard !Task.isCancelled, generation == request else { return }
                    succeeded += 1
                    if !available.contains(url) { available.append(url) }
                    urls = available
                    if selection == nil { selection = available.first }
                }
            }
            guard !Task.isCancelled, generation == request else { return }
            loading = false
            urls = available
            message = succeeded < files.count ? "Some attachments could not be previewed. Check their download status and try again." : ""
        }
    }
    func cancel() {
        generation = UUID()
        task?.cancel(); task = nil
        selection = nil; urls = []; loading = false; message = ""
    }
}
