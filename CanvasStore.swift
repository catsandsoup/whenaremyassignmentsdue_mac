import Foundation
import Combine
import AppKit

@MainActor
final class CanvasStore: ObservableObject {
    @Published var snapshot: CanvasSnapshot?
    @Published var syncing = false
    @Published var needsKey = false
    @Published var errorMessage: String?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lastAttempt = Date.distantPast
    private let cacheURL: URL
    private let client: CanvasAPIClient
    private let keyProvider: () -> String?
    private let automaticallyRefresh: Bool
    // The timetable represents the last successful download, not an expiring session.
    // Only a successful refresh moves this reference date forward.
    var displayedRows: [DeadlineRow] {
        let downloadedAt = snapshot.flatMap { Deadlines.date($0.checkedAt) } ?? Date()
        return Deadlines.rows(snapshot, now: downloadedAt)
    }

    init(cacheURL suppliedURL: URL? = nil, seedURL: URL? = Bundle.main.url(forResource: "Seed", withExtension: "json"), client: CanvasAPIClient = CanvasAPIClient(), keyProvider: @escaping () -> String? = TokenStore.read, automaticallyRefresh: Bool = true) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        cacheURL = suppliedURL ?? support.appendingPathComponent("AssignmentDates/Snapshot.json")
        self.client = client
        self.keyProvider = keyProvider
        self.automaticallyRefresh = automaticallyRefresh
        for url in [cacheURL, seedURL].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(CanvasSnapshot.self, from: data) {
                snapshot = saved
                break
            }
        }
        guard automaticallyRefresh else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refreshIfNeeded() {
        guard automaticallyRefresh else { return }
        if Date().timeIntervalSince(lastAttempt) > 300 { refresh() }
    }

    @discardableResult
    func refresh() -> Task<Void, Never>? {
        guard !syncing else { return nil }
        lastAttempt = Date()
        guard let key = keyProvider(), !key.isEmpty else {
            needsKey = true
            errorMessage = "Updates paused: no API key. Your saved timetable is unchanged."
            return nil
        }
        syncing = true
        return Task {
            defer { syncing = false }
            do {
                let updated = try await client.fetchSnapshot(token: key)
                let data = try JSONEncoder().encode(updated)
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: cacheURL, options: .atomic)
                snapshot = updated
                needsKey = false
                errorMessage = nil
            } catch CanvasAPIError.invalidKey {
                needsKey = true
                errorMessage = "Updates paused: API key expired or invalid. Your saved timetable is unchanged."
            } catch {
                // Network failures, throttling, and denied course access never trigger login.
                errorMessage = "Updates unavailable. Your saved timetable is unchanged."
            }
        }
    }

    func updateAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Canvas API key"
        alert.informativeText = "Paste your Canvas API key. The app uses it to refresh automatically."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = "Canvas API key"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save and refresh")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try TokenStore.save(field.stringValue); refresh() }
        catch { errorMessage = error.localizedDescription }
        field.stringValue = ""
    }
}
