import SwiftUI
import AppKit
import ServiceManagement
import Darwin

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
    private let client = CanvasAPIClient()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        cacheURL = support.appendingPathComponent("AssignmentDates/Snapshot.json")
        for url in [cacheURL, Bundle.main.url(forResource: "Seed", withExtension: "json")].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(CanvasSnapshot.self, from: data) {
                snapshot = saved
                break
            }
        }
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
        if Date().timeIntervalSince(lastAttempt) > 300 { refresh() }
    }

    func refresh() {
        guard !syncing else { return }
        lastAttempt = Date()
        guard let key = TokenStore.read(), !key.isEmpty else {
            needsKey = true
            errorMessage = "Add a Canvas API key to update automatically."
            return
        }
        syncing = true
        Task {
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
                errorMessage = "API key expired or invalid. Saved deadlines are available."
            } catch {
                // Network failures, throttling, and denied course access never trigger login.
                errorMessage = "Couldn't update. Showing saved deadlines."
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

struct AgendaAssignment: View {
    let row: DeadlineRow
    var title: String {
        if row.assignments.count > 2 {
            return row.assignments.allSatisfy { $0.name.lowercased().contains("group") } ? "Group assignment" : "Assignments"
        }
        return row.assignments.map(\.displayName).joined(separator: " and ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if row.assignments.count > 1 {
                Menu {
                    ForEach(row.assignments) { assignment in
                        if let url = canvasURL(assignment) { Link(assignment.name, destination: url) }
                    }
                } label: {
                    Text(title + (row.assignments.count > 2 ? " (\(row.assignments.count) submissions)" : ""))
                        .font(.body).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: false, vertical: true)
            } else if let assignment = row.assignments.first, let url = canvasURL(assignment) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Text(assignment.displayName).font(.body).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(assignment.name + " — open in Canvas")
                .accessibilityLabel(assignment.name + ", open in Canvas")
            } else { Text(title) }
            Text(row.course + " · " + Deadlines.timeLabel(row.due))
                .font(.subheadline).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.course + ", due " + Deadlines.label(row.due))
    }
    private func canvasURL(_ assignment: CanvasAssignment) -> URL? {
        guard let raw = assignment.html_url, let url = URL(string: raw),
              url.scheme == "https", url.host == "canvas.sydney.edu.au" else { return nil }
        return url
    }
}

struct DeadlinesView: View {
    @ObservedObject var store: CanvasStore
    @State private var loginError: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var days: [AgendaDay] { AgendaDay.grouped(Deadlines.rows(store.snapshot)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assignment Due Dates").font(.headline)
                Spacer()
                if store.syncing { ProgressView().controlSize(.small).accessibilityLabel("Updating deadlines") }
            }
            Divider()
            ViewThatFits(in: .vertical) {
                agenda
                ScrollView { agenda }.frame(height: 600)
            }.frame(maxHeight: 600)
            if days.isEmpty { Text("No upcoming dated assignments.") }
            Divider()
            HStack {
                if let error = store.errorMessage {
                    Text(error).font(.caption)
                } else if let checked = store.snapshot.flatMap({ Deadlines.date($0.checkedAt) }) {
                    Text("Sydney time · Updated " + Deadlines.timeLabel(checked)).font(.caption)
                        .help("Auto-refreshes every 30 minutes, on wake, and when reopened after 5 minutes.")
                }
                Spacer()
                if store.needsKey { Button("Replace API key") { store.updateAPIKey() } }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh").accessibilityLabel("Refresh").disabled(store.syncing)
                Menu {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                loginError = nil
                            } catch {
                                loginError = error.localizedDescription
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    Button("Update API key…") { store.updateAPIKey() }
                    Divider()
                    Button("Quit Assignment Dates") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton).fixedSize().help("Settings")
            }
            if let loginError { Text(loginError).font(.caption) }
        }
        .font(.body)
        .padding()
        .frame(width: 470)
        .onAppear { store.refreshIfNeeded() }
    }
    private var agenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Deadlines.dateLabel(day.date)).font(.headline)
                    ForEach(day.rows) { row in AgendaAssignment(row: row) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

@main
struct AssignmentDatesApp: App {
    @StateObject private var store = CanvasStore()
    init() {
        if CommandLine.arguments.contains("--store-api-key") {
            do {
                let input = FileHandle.standardInput.readDataToEndOfFile()
                guard let token = String(data: input, encoding: .utf8) else { exit(1) }
                try TokenStore.save(token)
                print("Canvas API key configured.")
                exit(0)
            } catch { print(error.localizedDescription); exit(1) }
        }
    }
    var body: some Scene {
        MenuBarExtra("Assignment Due Dates", systemImage: "calendar.badge.clock") {
            DeadlinesView(store: store)
        }.menuBarExtraStyle(.window)
        Window("Assignment Due Dates", id: "preview") { DeadlinesView(store: store) }
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(CommandLine.arguments.contains("--preview") ? .presented : .suppressed)
    }
}
