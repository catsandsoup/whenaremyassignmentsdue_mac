import SwiftUI
import ServiceManagement
import Combine

struct AssignmentSettings: View {
    @ObservedObject var store: CanvasStore
    @AppStorage("menuBarDisplay") private var display = "course"
    @AppStorage("menuBarShowIcon") private var showIcon = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

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
                Text("Shows the next future deadline. Days follow Sydney calendar dates; on the due date, the label says “due today”. Updates every minute, including offline.")
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
                Button("Update API key…") { store.updateAPIKey() }
            } header: { Text("Canvas") } footer: {
                Text("Your saved timetable stays available if the API key expires or Canvas cannot be reached.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .scenePadding()
    }
}
