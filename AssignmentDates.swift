import SwiftUI
import AppKit
import ServiceManagement
import Darwin

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
    @State private var showingUpdateWarning = false
    var days: [AgendaDay] { AgendaDay.grouped(store.displayedRows) }
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
                if let checked = store.snapshot.flatMap({ Deadlines.date($0.checkedAt) }) {
                    Text("Sydney time · Updated " + Deadlines.timeLabel(checked)).font(.caption)
                        .help("Last successful download: " + Deadlines.label(checked) + ". Saved dates remain available even when updates are unavailable.")
                }
                Spacer()
                if let error = store.errorMessage {
                    Button { showingUpdateWarning.toggle() } label: {
                        Image(systemName: "exclamationmark.triangle.fill").symbolRenderingMode(.multicolor)
                    }
                    .buttonStyle(.plain)
                    .help(error)
                    .accessibilityLabel("Updates unavailable. Your saved timetable is unchanged.")
                    .popover(isPresented: $showingUpdateWarning) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Updates paused").font(.headline)
                            Text(error)
                            if store.needsKey {
                                Button("Update API key…") { showingUpdateWarning = false; store.updateAPIKey() }
                            }
                            Button("Retry update") { showingUpdateWarning = false; store.refresh() }.disabled(store.syncing)
                        }.padding().frame(width: 300)
                    }
                }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh").accessibilityLabel("Refresh").disabled(store.syncing)
                Menu {
                    Button("Marks & Feedback…") { MenuBarAppDelegate.controller?.showFeedback() }
                    Button("Settings…") { MenuBarAppDelegate.controller?.showSettings() }.keyboardShortcut(",")
                    Divider()
                    Button("Quit Assignment Dates") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton).fixedSize().help("Settings")
            }
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
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
    @StateObject private var store: CanvasStore
    @StateObject private var feedback: FeedbackStore
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
        let arguments = CommandLine.arguments
        let design = arguments.contains("--marks-design-preview")
        let offline = arguments.contains("--feedback-offline")
        let dataDirectory = arguments.firstIndex(of: "--feedback-data-dir").flatMap { index in
            arguments.indices.contains(index + 1) ? URL(fileURLWithPath: arguments[index + 1], isDirectory: true) : nil
        }
        _feedback = StateObject(wrappedValue: FeedbackStore(designMode: design, directory: dataDirectory, automaticallyRefresh: !design && !offline))
        let previewExpiredKey = CommandLine.arguments.contains("--preview-expired-key")
        let initial = CanvasStore(automaticallyRefresh: !previewExpiredKey && !design && !offline)
        if previewExpiredKey {
            initial.needsKey = true
            initial.errorMessage = "Updates paused: API key expired or invalid. Your saved timetable is unchanged."
        }
        _store = StateObject(wrappedValue: initial)
        MenuBarAppDelegate.store = initial
    }
    var body: some Scene {
        Window("Marks & Feedback", id: "marks-feedback") {
            FeedbackWindowView(store: feedback)
                .preferredColorScheme(CommandLine.arguments.contains("--appearance-dark") ? .dark : CommandLine.arguments.contains("--appearance-light") ? .light : nil)
        }
        .defaultSize(width: 1100, height: 760)
        .defaultLaunchBehavior(CommandLine.arguments.contains("--marks-design-preview") || CommandLine.arguments.contains("--marks") ? .presented : .suppressed)
        Window("Assignment Due Dates", id: "preview") { DeadlinesView(store: store) }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { MenuBarAppDelegate.controller?.showSettings() }.keyboardShortcut(",")
                }
                CommandGroup(after: .appSettings) {
                    Button("Marks & Feedback…") { MenuBarAppDelegate.controller?.showFeedback() }.keyboardShortcut("m", modifiers: [.command, .shift])
                }
            }
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(CommandLine.arguments.contains("--preview") ? .presented : .suppressed)
    }
}
