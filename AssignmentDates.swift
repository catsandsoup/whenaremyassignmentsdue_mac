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
                        Button { MenuBarAppDelegate.controller?.showAssignment(assignment.id) } label: {
                            Text(assignment.name + (assignment.isSubmitted ? " — Submitted" : ""))
                                .strikethrough(assignment.isSubmitted)
                        }
                    }
                } label: {
                    Text(title + (row.assignments.count > 2 ? " (\(row.assignments.count) submissions)" : ""))
                        .strikethrough(row.isSubmitted)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading).contentShape(Rectangle())
                        .feedbackFont(.body).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: false, vertical: true)
            } else if let assignment = row.assignments.first {
                Button { MenuBarAppDelegate.controller?.showAssignment(assignment.id) } label: {
                    Text(assignment.displayName).strikethrough(assignment.isSubmitted).feedbackFont(.body).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(assignment.name + " — open assignment")
                .accessibilityLabel(assignment.name + (assignment.isSubmitted ? ", submitted" : "") + ", open assignment")
            } else { Text(title) }
            Text(row.course + " · " + Deadlines.timeLabel(row.due) + (row.submissionLabel.map { " · " + $0 } ?? ""))
                .feedbackFont(.callout).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
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
    @AppStorage("feedbackReadingSize") private var readingStep = 0
    @State private var agendaHeight: CGFloat = 420
    var days: [AgendaDay] { AgendaDay.grouped(store.displayedRows) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assignment Due Dates").feedbackFont(.headline)
                Spacer()
                if store.syncing { ProgressView().controlSize(.small).accessibilityLabel("Updating deadlines") }
            }
            Divider()
            if days.isEmpty { Text("No upcoming dated assignments.") }
            else {
                ScrollView {
                    agenda.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { agendaHeight = $0 }
                }
                .frame(height: min(agendaHeight, max(200, min(560, (NSScreen.main?.visibleFrame.height ?? 800) - 200)) ))
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let checked = store.snapshot.flatMap({ Deadlines.date($0.checkedAt) }) {
                    Text("Sydney time · Updated " + Deadlines.timeLabel(checked)).feedbackFont(.callout)
                        .help("Last successful download: " + Deadlines.label(checked) + ". Saved dates remain available even when updates are unavailable.")
                }
                HStack(spacing: 10) {
                Button("Assignments…") { MenuBarAppDelegate.controller?.showFeedback() }.controlSize(.large)
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
                            Text("Updates paused").feedbackFont(.headline)
                            Text(error)
                            if store.needsKey {
                                Button("Update API key…") { showingUpdateWarning = false; store.updateAPIKey() }
                            }
                            Button("Retry update") { showingUpdateWarning = false; store.refresh() }.disabled(store.syncing)
                        }.padding().frame(width: 300)
                    }
                }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .controlSize(.large).help("Refresh deadlines").accessibilityLabel("Refresh deadlines").disabled(store.syncing)
                Menu {
                    Button("Assignments…") { MenuBarAppDelegate.controller?.showFeedback() }
                    Button("Module Files…") { MenuBarAppDelegate.controller?.showModules() }
                    Button("Settings…") { MenuBarAppDelegate.controller?.showSettings() }.keyboardShortcut(",")
                    Divider()
                    Button("Quit Assignment Dates") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                .controlSize(.large).menuStyle(.borderlessButton).fixedSize().frame(minWidth: 32, minHeight: 32).contentShape(Rectangle()).help("Settings and app commands")
                }
            }
        }
        .feedbackFont(.body)
        .padding()
        .frame(width: 470)
        .environment(\.feedbackReadingStep, FeedbackReadingSize.clamped(readingStep))
        .onAppear { store.refreshIfNeeded() }
    }
    private var agenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Calendar.current.isDateInToday(day.date) ? "Today · " + Deadlines.dateLabel(day.date) : Deadlines.dateLabel(day.date)).feedbackFont(.headline)
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
        let initialFeedback = FeedbackStore(designMode: design, directory: dataDirectory, automaticallyRefresh: !design && !offline)
        _feedback = StateObject(wrappedValue: initialFeedback)
        MenuBarAppDelegate.feedback = initialFeedback
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
        Window("Assignment Due Dates", id: "preview") { DeadlinesView(store: store) }
            .commands {
                FeedbackReadingCommands()
                CommandGroup(replacing: .appSettings) {
                    Button("Module Files…") { MenuBarAppDelegate.controller?.showModules() }
                    Button("Settings…") { MenuBarAppDelegate.controller?.showSettings() }.keyboardShortcut(",")
                }
                CommandGroup(after: .appSettings) {
                    Button("Assignments…") { MenuBarAppDelegate.controller?.showFeedback() }.keyboardShortcut("m", modifiers: [.command, .shift])
                }
            }
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(CommandLine.arguments.contains("--preview") ? .presented : .suppressed)
    }
}

// Keep the window and its openWindow action in the same hosting scene graph.
struct MarksFeedbackScene: Scene {
    @ObservedObject var feedback: FeedbackStore
    var body: some Scene {
        Window("Assignments", id: "marks-feedback") {
            FeedbackWindowView(store: feedback)
                .preferredColorScheme(CommandLine.arguments.contains("--appearance-dark") ? .dark : CommandLine.arguments.contains("--appearance-light") ? .light : nil)
        }
        .commands { FeedbackReadingCommands() }
        .defaultSize(width: 1100, height: 760)
        .defaultLaunchBehavior(CommandLine.arguments.contains("--marks-design-preview") || CommandLine.arguments.contains("--marks") ? .presented : .suppressed)
    }
}
