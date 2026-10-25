import SwiftUI
import ServiceManagement
import Combine

struct AssignmentSettings: View {
    @ObservedObject var store: CanvasStore
    @AppStorage("menuBarDisplay") private var display = "course"
    @AppStorage("menuBarShowIcon") private var showIcon = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage("feedbackReadingSize") private var readingStep = 0

    var body: some View {
        Form {
            Section {
                Picker("Show in menu bar", selection: $display) {
                    Text("Course and countdown").tag("course")
                    Text("Countdown only").tag("countdown")
                    Text("Icon only").tag("icon")
                }
                Toggle("Show calendar icon", isOn: $showIcon).disabled(display == "icon")
                LabeledContent("Preview") {
                    Text(display == "icon" ? "" : MenuBarDeadline.text(rows: store.displayedRows, now: Date(), countdownOnly: display == "countdown") ?? "No upcoming deadlines")
                    if display == "icon" || showIcon { Image(systemName: "calendar.badge.clock") }
                }
            } header: { Text("Menu Bar") } footer: {
                Text("Shows your next deadline using Sydney dates. The countdown updates every minute, including offline.")
            }
            Section("Reading") {
                Picker("Text size", selection: $readingStep) {
                    ForEach(0...FeedbackReadingSize.maximum, id: \.self) { step in
                        Text("\(100 + step * 10)%").tag(step)
                    }
                }
                Text("Applies to assignments, feedback and the menu bar agenda.").feedbackFont(.callout).foregroundStyle(.secondary)
            }
            Section("General") {
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
                if let loginError { Text(loginError).foregroundStyle(.secondary) }
            }
            Section {
                LabeledContent("Automatic updates", value: "Every 30 minutes")
                if let checked = store.snapshot?.checkedAt { LabeledContent("Last updated", value: FeedbackFormat.time(checked)) }
                if store.errorMessage != nil { Text("Updates paused. Your saved timetable remains available.").feedbackFont(.callout) }
                Button("Update API key…") { store.updateAPIKey() }
            } header: { Text("Canvas") } footer: {
                Text("Your saved timetable stays available if the API key expires or Canvas cannot be reached.")
            }
        }
        .formStyle(.grouped)
        .feedbackFont(.body)
        .environment(\.feedbackReadingStep, FeedbackReadingSize.clamped(readingStep))
        .frame(width: 490, height: min(760, (NSScreen.main?.visibleFrame.height ?? 900) - 100))
        .scenePadding()
        .windowMinimizeBehavior(.enabled)
    }
}
