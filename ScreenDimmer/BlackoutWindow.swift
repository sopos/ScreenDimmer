import Cocoa
import CoreGraphics

class BlackoutWindow: NSWindow {
    private let clockLabel = NSTextField(labelWithString: "")
    private var clockTimer: Timer?
    var showClock = false

    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .init(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        acceptsMouseMovedEvents = true

        let contentView = BlackoutView(frame: screen.frame)
        self.contentView = contentView

        clockLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .thin)
        clockLabel.textColor = NSColor.white.withAlphaComponent(0.3)
        clockLabel.alignment = .center
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clockLabel)

        NSLayoutConstraint.activate([
            clockLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            clockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func startClock() {
        updateClock()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func updateClock() {
        guard showClock else {
            clockLabel.stringValue = ""
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockLabel.stringValue = formatter.string(from: Date())
    }
}

class BlackoutView: NSView {
    private static let transparentCursor: NSCursor = {
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: .zero)
    }()

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func keyDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: Self.transparentCursor)
    }
}

class BlackoutManager {
    static let shared = BlackoutManager()

    private var windows: [BlackoutWindow] = []
    private(set) var isShowingBlackout = false
    var showClock = false
    private(set) var blackoutStartTime: Date?

    func showBlackout() {
        guard !isShowingBlackout else { return }
        isShowingBlackout = true
        blackoutStartTime = Date()

        NSApp.activate(ignoringOtherApps: true)

        for screen in NSScreen.screens {
            let window = BlackoutWindow(screen: screen)
            window.showClock = showClock
            window.makeKeyAndOrderFront(nil)
            window.startClock()
            windows.append(window)
        }

        if let firstWindow = windows.first, let view = firstWindow.contentView {
            firstWindow.makeFirstResponder(view)
        }
    }

    func hideBlackout() {
        guard isShowingBlackout else { return }
        isShowingBlackout = false
        blackoutStartTime = nil

        for window in windows {
            window.stopClock()
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}
