import Cocoa
import ServiceManagement
import SwiftUI

@main
struct ScreenDimmerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var idleMonitor: IdleMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        idleMonitor = IdleMonitor.shared

        for window in NSApp.windows {
            window.close()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "ScreenDimmer")
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let enableItem = NSMenuItem(
            title: idleMonitor.isEnabled ? "Enabled" : "Disabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.state = idleMonitor.isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(.separator())

        let powerSource = idleMonitor.isOnAC ? "⚡ On AC" : "🔋 On Battery"
        let powerItem = NSMenuItem(title: powerSource, action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)

        menu.addItem(.separator())

        let acHeader = NSMenuItem(title: "On AC, dim after:", action: nil, keyEquivalent: "")
        acHeader.isEnabled = false
        menu.addItem(acHeader)

        for minutes in [1, 2, 5, 10, 15, 30] {
            let label = minutes == 1 ? "  1 minute" : "  \(minutes) minutes"
            let item = NSMenuItem(
                title: label,
                action: #selector(setTimeoutAC(_:)),
                keyEquivalent: ""
            )
            item.tag = minutes
            item.state = idleMonitor.timeoutMinutesAC == minutes ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let batteryHeader = NSMenuItem(title: "On Battery, dim after:", action: nil, keyEquivalent: "")
        batteryHeader.isEnabled = false
        menu.addItem(batteryHeader)

        for minutes in [1, 2, 5, 10, 15, 30] {
            let label = minutes == 1 ? "  1 minute" : "  \(minutes) minutes"
            let item = NSMenuItem(
                title: label,
                action: #selector(setTimeoutBattery(_:)),
                keyEquivalent: ""
            )
            item.tag = minutes
            item.state = idleMonitor.timeoutMinutesBattery == minutes ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let clockItem = NSMenuItem(
            title: "Show Clock",
            action: #selector(toggleClock),
            keyEquivalent: ""
        )
        clockItem.state = idleMonitor.showClock ? .on : .off
        menu.addItem(clockItem)

        let loginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let testItem = NSMenuItem(
            title: "Test Blackout Now",
            action: #selector(testBlackout),
            keyEquivalent: "t"
        )
        menu.addItem(testItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit ScreenDimmer",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        idleMonitor.isEnabled.toggle()
        buildMenu()

        if let button = statusItem.button {
            let iconName = idleMonitor.isEnabled ? "moon.fill" : "moon"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ScreenDimmer")
        }
    }

    @objc private func setTimeoutAC(_ sender: NSMenuItem) {
        idleMonitor.timeoutMinutesAC = sender.tag
        buildMenu()
    }

    @objc private func setTimeoutBattery(_ sender: NSMenuItem) {
        idleMonitor.timeoutMinutesBattery = sender.tag
        buildMenu()
    }

    @objc private func toggleClock() {
        idleMonitor.showClock.toggle()
        buildMenu()
    }

    @objc private func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {}
        buildMenu()
    }

    @objc private func testBlackout() {
        BlackoutManager.shared.showClock = idleMonitor.showClock
        BlackoutManager.shared.showBlackout()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
