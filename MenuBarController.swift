import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    static var store: CanvasStore?
    static var controller: MenuBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store = Self.store else { return }
        Self.controller = MenuBarController(store: store)
    }
}

// AppKit supplies status-item mouse handling; all agenda/settings content remains SwiftUI.
@MainActor
final class MenuBarController: NSObject {
    private let store: CanvasStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settingsScene: NSHostingSceneRepresentation<Settings<AssignmentSettings>>
    private var observers: Set<AnyCancellable> = []

    init(store: CanvasStore) {
        self.store = store
        settingsScene = NSHostingSceneRepresentation { Settings { AssignmentSettings(store: store) } }
        super.init()
        NSApp.addSceneRepresentation(settingsScene)
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
        NSApp.activate(ignoringOtherApps: true)
        settingsScene.environment.openSettings()
    }
    @objc private func settingsClicked() { showSettings() }
    @objc private func refreshClicked() { store.refresh() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
