import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    static var store: CanvasStore?
    static var feedback: FeedbackStore?
    static var controller: MenuBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store = Self.store, let feedback = Self.feedback else { return }
        Self.controller = MenuBarController(store: store, feedback: feedback)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.controller?.restoreWindowFromDock()
        return false
    }
}

// AppKit supplies status-item mouse handling; all agenda/settings content remains SwiftUI.
@MainActor
final class MenuBarController: NSObject {
    private let feedback: FeedbackStore
    private let store: CanvasStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settingsScene: NSHostingSceneRepresentation<Settings<AssignmentSettings>>
    private let feedbackScene: NSHostingSceneRepresentation<MarksFeedbackScene>
    private var observers: Set<AnyCancellable> = []
    private let openWindows = NSHashTable<NSWindow>.weakObjects()
    private weak var lastMainWindow: NSWindow?

    init(store: CanvasStore, feedback: FeedbackStore) {
        self.store = store; self.feedback = feedback
        settingsScene = NSHostingSceneRepresentation { Settings { AssignmentSettings(store: store) } }
        feedbackScene = NSHostingSceneRepresentation { MarksFeedbackScene(feedback: feedback) }
        super.init()
        observeWindowLifecycle()
        NSApp.addSceneRepresentation(settingsScene)
        NSApp.addSceneRepresentation(feedbackScene)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DeadlinesView(store: store))
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateLabel()
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.updateLabel() }.store(in: &observers)
        store.$snapshot.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }.store(in: &observers)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }.store(in: &observers)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }.store(in: &observers)
    }

    private func updateLabel() {
        guard let button = item.button else { return }
        let defaults = UserDefaults.standard
        let display = defaults.string(forKey: "menuBarDisplay") ?? "course"
        let text = MenuBarDeadline.text(rows: store.displayedRows, now: Date(), countdownOnly: display == "countdown")
        button.title = display == "icon" ? "" : text ?? ""
        let showIcon = display == "icon" || defaults.bool(forKey: "menuBarShowIcon") || text == nil
        button.image = showIcon ? NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Assignment Due Dates") : nil
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.font = .menuBarFont(ofSize: 0)
        button.toolTip = text ?? "Open your saved timetable"
        button.setAccessibilityLabel(text ?? "Assignment Due Dates")
    }

    @objc private func clicked(_ sender: Any?) {
        guard let button = item.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            popover.performClose(nil)
            let menu = NSMenu()
            let marks = menu.addItem(withTitle: "Assignments…", action: #selector(feedbackClicked), keyEquivalent: "")
            marks.target = self
            let modules = menu.addItem(withTitle:"Module Files…",action:#selector(modulesClicked),keyEquivalent:""); modules.target = self
            let settings = menu.addItem(withTitle: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
            settings.target = self
            let refresh = menu.addItem(withTitle: "Refresh", action: #selector(refreshClicked), keyEquivalent: "")
            refresh.target = self
            menu.addItem(.separator())
            let quit = menu.addItem(withTitle: "Quit Assignment Dates", action: #selector(quitClicked), keyEquivalent: "q")
            quit.target = self
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showSettings() {
        popover.performClose(nil)
        activateWindowedApp()
        settingsScene.environment.openSettings()
    }
    func showFeedback() {
        popover.performClose(nil)
        activateWindowedApp()
        feedbackScene.environment.openWindow(id: "marks-feedback")
    }
    func showAssignment(_ assignmentID: Int) {
        feedback.moduleFilesRequested = false; feedback.requestedAssignmentID = assignmentID
        showFeedback()
    }
    func showModules() { feedback.moduleFilesRequested = true; showFeedback() }
    private func activateWindowedApp() {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeWindowLifecycle() {
        NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)
            .sink { [weak self] notification in
                guard let self, let window = notification.object as? NSWindow,
                      !(window is NSPanel), window.level == .normal else { return }
                self.openWindows.add(window)
                self.lastMainWindow = window
                // Also covers windows presented by launch arguments or the Window menu.
                self.activateWindowedApp()
            }.store(in: &observers)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] notification in
                guard let self, let window = notification.object as? NSWindow,
                      self.openWindows.contains(window) else { return }
                self.openWindows.remove(window)
                // Wait until AppKit has finished closing the window before hiding the Dock icon.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.openWindows.allObjects.isEmpty else { return }
                    NSApp.setActivationPolicy(.accessory)
                }
            }.store(in: &observers)
    }

    func restoreWindowFromDock() {
        let windows = openWindows.allObjects
        let window = lastMainWindow.flatMap { candidate in windows.first { $0 === candidate } } ?? windows.first
        guard let window else { showFeedback(); return }
        activateWindowedApp()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func feedbackClicked() { showFeedback() }
    @objc private func modulesClicked() { showModules() }
    @objc private func settingsClicked() { showSettings() }
    @objc private func refreshClicked() { store.refresh() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
