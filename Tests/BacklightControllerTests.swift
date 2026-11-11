import Foundation
import CoreGraphics

private final class FakeBrightnessBackend: DisplayBrightnessBackend {
    var level: Float? = 0.65
    var automatic: Bool? = true
    var failZero = false
    var failRestore = false
    var failAutomatic = false
    var writes: [String] = []

    func brightness(of display: CGDirectDisplayID) -> Float? { level }
    func automaticBrightness(of display: CGDirectDisplayID) -> Bool? { automatic }

    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        writes.append("brightness:\(value)")
        if (value == 0 && failZero) || (value != 0 && failRestore) { return false }
        level = value
        return true
    }

    func setAutomaticBrightness(_ enabled: Bool, of display: CGDirectDisplayID) -> Bool {
        writes.append("automatic:\(enabled)")
        if failAutomatic { return false }
        automatic = enabled
        return true
    }
}

@main
struct BacklightControllerTests {
    static func main() {
        // Round trips preserve both manual and automatic settings, including zero.
        for automatic in [false, true] {
            for level in [Float(0), 0.25, 1] {
                let backend = FakeBrightnessBackend()
                backend.level = level
                backend.automatic = automatic
                let controller = BacklightController(backend: backend)
                precondition(controller.turnOff(1))
                precondition(backend.level == 0 && backend.automatic == false)
                precondition(!controller.turnOff(1), "Repeated blackout must keep the original state")
                backend.writes.removeAll()
                controller.restore()
                precondition(backend.level == level && backend.automatic == automatic)
                precondition(backend.writes == ["brightness:\(level)", "automatic:\(automatic)"])
                backend.writes.removeAll()
                controller.restore()
                precondition(backend.writes.isEmpty, "Restoring twice must be harmless")
            }
        }

        // Never change anything unless both original settings can be read.
        for missingBrightness in [false, true] {
            let backend = FakeBrightnessBackend()
            if missingBrightness { backend.level = nil } else { backend.automatic = nil }
            let controller = BacklightController(backend: backend)
            precondition(!controller.turnOff(1))
            precondition(backend.writes.isEmpty)
        }

        // A failed zero write rolls back the automatic-brightness change.
        do {
            let backend = FakeBrightnessBackend()
            backend.failZero = true
            let controller = BacklightController(backend: backend)
            precondition(!controller.turnOff(1))
            precondition(backend.level == 0.65 && backend.automatic == true)
        }

        // Do not dim if automatic adjustment cannot be disabled.
        do {
            let backend = FakeBrightnessBackend()
            backend.failAutomatic = true
            let controller = BacklightController(backend: backend)
            precondition(!controller.turnOff(1))
            precondition(!backend.writes.contains("brightness:0.0"))
            backend.failAutomatic = false
            controller.restore()
            precondition(backend.level == 0.65 && backend.automatic == true)
        }

        // Keep the saved values across partial restoration failures.
        for failBrightness in [false, true] {
            let backend = FakeBrightnessBackend()
            let controller = BacklightController(backend: backend)
            precondition(controller.turnOff(1))
            backend.failRestore = failBrightness
            backend.failAutomatic = !failBrightness
            controller.restore()
            precondition(!controller.turnOff(1), "Pending restoration must not overwrite saved values")
            backend.failRestore = false
            backend.failAutomatic = false
            controller.restore()
            precondition(backend.level == 0.65 && backend.automatic == true)

            // The next session captures a fresh value.
            backend.level = 0.4
            backend.automatic = false
            precondition(controller.turnOff(1))
            controller.restore()
            precondition(backend.level == 0.4 && backend.automatic == false)
        }
        // A failed restore also recovers without another user event.
        do {
            let backend = FakeBrightnessBackend()
            let controller = BacklightController(backend: backend)
            precondition(controller.turnOff(1))
            backend.failRestore = true
            controller.restore()
            backend.failRestore = false
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
            precondition(backend.level == 0.65 && backend.automatic == true)
            backend.writes.removeAll()
            controller.restore()
            precondition(backend.writes.isEmpty)
        }
        print("BacklightController tests passed")
    }
}
