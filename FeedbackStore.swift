import Foundation
import Combine
import AppKit

@MainActor final class FeedbackStore: ObservableObject {
    @Published var items: [FeedbackItem] = []
    @Published var syncing = false
    @Published var errorMessage: String?
    @Published var checkedAt: String?
    @Published var busyFiles = Set<String>()
    @Published var fileErrors: [String: String] = [:]
    let designMode: Bool
    let directory: URL
    private let api: FeedbackAPI
    private let keyProvider: () -> String?
    private let automaticallyRefresh: Bool
    private var repository: FeedbackRepository?
    private let files: FeedbackFiles
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lastAttempt = Date.distantPast
    private var loading: Task<Void, Never>?
    init(designMode: Bool = false, directory: URL? = nil, api: FeedbackAPI = FeedbackAPI(), keyProvider: @escaping () -> String? = TokenStore.read, automaticallyRefresh: Bool = true) {
        self.designMode = designMode; self.api = api; self.keyProvider = keyProvider; self.automaticallyRefresh = automaticallyRefresh
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.directory = directory ?? support.appendingPathComponent("AssignmentDates/Feedback")
        files = FeedbackFiles(directory: self.directory)
        if designMode { items = FeedbackDesignFixture.items; checkedAt = "2026-10-15T06:21:00Z"; return }
        loading = Task { [weak self] in
            guard let self else { return }
            do {
                let repository = try FeedbackRepository.open(directory: self.directory)
                self.repository = repository
                self.items = try await repository.load()
                self.checkedAt = try await repository.lastCheckedAt()
                if automaticallyRefresh { self.refresh() }
            } catch { self.errorMessage = "Could not open the saved feedback store. It has been preserved for recovery. " + error.localizedDescription }
        }
        guard automaticallyRefresh else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshIfNeeded() } }
    }
    func waitForLoad() async { await loading?.value }
    func refreshIfNeeded() {
        guard !designMode, automaticallyRefresh, Date().timeIntervalSince(lastAttempt) > 300 else { return }
        refresh()
    }
    @discardableResult func refresh() -> Task<Void, Never>? {
        guard !designMode, !syncing, let repository else { return nil }
        lastAttempt = Date()
        guard let token = keyProvider(), !token.isEmpty else {
            errorMessage = "Updates paused: no API key. Your saved feedback and PDFs remain available."; return nil
        }
        syncing = true
        return Task {
            defer { syncing = false }
            do {
                let result = try await api.fetch(token: token)
                try Task.checkCancellation()
                items = try await repository.merge(result)
                checkedAt = try await repository.lastCheckedAt()
                let warnings = result.courses.compactMap(\.warning)
                errorMessage = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
                let snapshots = items
                for item in snapshots {
                    for file in item.attachments where file.isPDF && localURL(file) == nil {
                        _ = await obtain(file, itemID: item.id)
                    }
                }
                if !fileErrors.isEmpty, errorMessage == nil { errorMessage = "Some attachments could not be downloaded. Your saved feedback and existing PDFs remain available." }
            } catch CanvasAPIError.invalidKey {
                errorMessage = "Updates paused: API key expired or invalid. Your saved feedback and PDFs remain available."
            } catch is CancellationError {
                errorMessage = "Update cancelled. Your saved feedback and PDFs remain available."
            } catch {
                errorMessage = "Updates unavailable. Your saved feedback and PDFs remain available. " + error.localizedDescription
            }
        }
    }
    func localURL(_ file: FeedbackAttachment) -> URL? { FeedbackFiles.localURL(file, directory: directory) }
    func obtain(_ file: FeedbackAttachment, itemID: String) async -> URL? {
        guard !designMode, let repository else { return nil }
        let key = itemID + ":" + String(file.id)
        guard !busyFiles.contains(key) else { return nil }
        busyFiles.insert(key); fileErrors[key] = nil
        defer { busyFiles.remove(key) }
        do {
            let saved = try await files.obtain(file, token: keyProvider() ?? "")
            items = try await repository.updateAttachment(itemID: itemID, file: saved, expected: file)
            return localURL(saved)
        } catch {
            fileErrors[key] = "Could not open this attachment. " + error.localizedDescription
            return nil
        }
    }
    func duplicateSource(_ file: FeedbackAttachment, itemID: String) -> String? {
        guard let hash = file.contentHash, let current = items.first(where: { $0.id == itemID }) else { return nil }
        return items.filter { $0.id != itemID && $0.attachments.contains { $0.contentHash == hash } && $0.recentDate < current.recentDate }.sorted { $0.recentDate < $1.recentDate }.first?.title
    }
}
