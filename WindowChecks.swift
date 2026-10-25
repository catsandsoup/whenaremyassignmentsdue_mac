import SwiftUI
import AppKit

// Exercise the real scenes/controller, without network access or real feedback records.
@main
struct WindowChecksApp: App {
    private let app = AssignmentDatesApp()
    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                // Match the installed app's LSUIElement launch policy.
                NSApp.setActivationPolicy(.accessory)
                await settle()
                guard let controller = MenuBarAppDelegate.controller else { fail("Menu controller missing") }
                controller.showFeedback()
                await settle()
                guard let marks = feedbackWindow(), marks.isVisible else { fail("Marks action did not present its window") }
                func menuTitles(_ menu:NSMenu) -> [String] { menu.items.flatMap { [$0.title] + ($0.submenu.map(menuTitles) ?? []) } }
                check(NSApp.mainMenu.map(menuTitles)?.contains("Larger Text") == true,"Reading size commands must be in the native app menu")
                check(NSApp.activationPolicy() == .regular, "Opening Marks must show the app in the Dock")
                check(marks.styleMask.contains(.miniaturizable), "Marks must support native minimisation")
                controller.showFeedback()
                await settle()
                check(NSApp.windows.filter { $0.title == "Assignments" && $0.isVisible }.count == 1, "Repeated action must reuse one window")
                marks.miniaturize(nil)
                await settle()
                check(marks.isMiniaturized, "Marks must minimise")
                check(NSApp.activationPolicy() == .regular, "Minimising must keep the Dock icon")
                _ = NSApp.delegate?.applicationShouldHandleReopen?(NSApp, hasVisibleWindows: true)
                await settle()
                check(!marks.isMiniaturized && marks.isVisible, "Dock reopen must restore minimised Marks")
                controller.showModules()
                await settle()
                check(marks.title == "Module Files" && marks.isVisible,"Module Files must open in the main Dock window")
                marks.miniaturize(nil); await settle()
                _ = NSApp.delegate?.applicationShouldHandleReopen?(NSApp,hasVisibleWindows:true)
                await settle()
                check(!marks.isMiniaturized && marks.isVisible,"Module Files must restore from the Dock")
                MenuBarAppDelegate.feedback?.moduleFilesRequested = false
                await settle()
                controller.showSettings()
                await settle()
                guard let settings = NSApp.windows.first(where: { $0 !== marks && $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }) else { fail("Settings did not open") }
                marks.close()
                await settle()
                check(NSApp.activationPolicy() == .regular, "Closing Marks must keep the Dock while Settings is open")
                check(settings.styleMask.contains(.miniaturizable), "Settings must support native minimisation")
                settings.miniaturize(nil)
                await settle()
                check(settings.isMiniaturized && NSApp.activationPolicy() == .regular, "Minimised Settings must remain in the Dock")
                _ = NSApp.delegate?.applicationShouldHandleReopen?(NSApp, hasVisibleWindows: true)
                await settle()
                check(settings.isVisible && !settings.isMiniaturized, "Dock reopen must restore Settings")
                settings.close()
                await settle()
                check(NSApp.activationPolicy() == .accessory, "Closing all windows must return to menu bar only")
                controller.showSettings()
                await settle()
                check(NSApp.activationPolicy() == .regular, "Settings alone must show the Dock icon")
                check(settings.isVisible, "Closed Settings must reopen")
                settings.close()
                await settle()
                controller.showFeedback()
                await settle()
                check(feedbackWindow()?.isVisible == true, "Closed Marks must reopen")
                print("PASS: Marks and Settings promote to Dock, minimise/restore, reuse/reopen, and return to menu bar only after the last window closes")
                exit(0)
            }
        }
    }
    var body: some Scene { app.body }
}

@MainActor private func settle() async { try? await Task.sleep(for: .milliseconds(700)) }
@MainActor private func feedbackWindow() -> NSWindow? { NSApp.windows.first { $0.title == "Assignments" } }
private func check(_ condition: Bool, _ message: String) { if !condition { fail(message) } }
private func fail(_ message: String) -> Never { print("FAIL: " + message); exit(1) }
