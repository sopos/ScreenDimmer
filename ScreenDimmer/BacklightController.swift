import Foundation
import CoreGraphics
import Darwin

protocol DisplayBrightnessBackend {
    func brightness(of display: CGDirectDisplayID) -> Float?
    func automaticBrightness(of display: CGDirectDisplayID) -> Bool?
    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool
    func setAutomaticBrightness(_ enabled: Bool, of display: CGDirectDisplayID) -> Bool
}

// DisplayServices is private API. Resolve its symbols at runtime so an unsupported
// macOS version can still use the usual black overlay without changing settings.
final class DisplayServicesBackend: DisplayBrightnessBackend {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private typealias GetAutomatic = @convention(c) (UInt32, UnsafeMutablePointer<Bool>) -> Int32
    private typealias SetAutomatic = @convention(c) (UInt32, Bool) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let brightnessGetter: GetBrightness?
    private let brightnessSetter: SetBrightness?
    private let automaticGetter: GetAutomatic?
    private let automaticSetter: SetAutomatic?

    init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY | RTLD_LOCAL
        )
        self.handle = handle
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let address = dlsym(handle, name) else { return nil }
            return unsafeBitCast(address, to: type)
        }
        brightnessGetter = symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
        brightnessSetter = symbol("DisplayServicesSetBrightness", as: SetBrightness.self)
        automaticGetter = symbol("DisplayServicesAmbientLightCompensationEnabled", as: GetAutomatic.self)
        automaticSetter = symbol("DisplayServicesEnableAmbientLightCompensation", as: SetAutomatic.self)
    }

    func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard let brightnessGetter, brightnessSetter != nil,
              brightnessGetter(display, &value) == 0,
              value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    func automaticBrightness(of display: CGDirectDisplayID) -> Bool? {
        var enabled = false
        guard let automaticGetter, automaticSetter != nil,
              automaticGetter(display, &enabled) == 0 else { return nil }
        return enabled
    }

    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        brightnessSetter?(display, value) == 0
    }

    func setAutomaticBrightness(_ enabled: Bool, of display: CGDirectDisplayID) -> Bool {
        automaticSetter?(display, enabled) == 0
    }

    deinit {
        if let handle { dlclose(handle) }
    }
}

final class BacklightController {
    private struct SavedState {
        let brightness: Float
        let automatic: Bool
    }

    private let backend: DisplayBrightnessBackend
    private var savedStates: [CGDirectDisplayID: SavedState] = [:]
    private var restoreTimer: Timer?

    init(backend: DisplayBrightnessBackend = DisplayServicesBackend()) {
        self.backend = backend
    }

    @discardableResult
    func turnOff(_ display: CGDirectDisplayID) -> Bool {
        // Never replace the original values with our own zero/disabled values.
        guard savedStates[display] == nil else { return false }
        guard let brightness = backend.brightness(of: display),
              let automatic = backend.automaticBrightness(of: display) else {
            NSLog("ScreenDimmer: cannot save backlight settings for display %u; using overlay", display)
            return false
        }

        savedStates[display] = SavedState(brightness: brightness, automatic: automatic)
        guard (!automatic || backend.setAutomaticBrightness(false, of: display)),
              backend.setBrightness(0, of: display) else {
            NSLog("ScreenDimmer: cannot turn off backlight for display %u; restoring settings", display)
            restore()
            return false
        }
        return true
    }

    func restore() {
        for (display, state) in savedStates {
            // Restore the level before re-enabling the ambient light sensor.
            let brightnessRestored = backend.setBrightness(state.brightness, of: display)
            let automaticRestored = backend.setAutomaticBrightness(state.automatic, of: display)
            if brightnessRestored && automaticRestored {
                savedStates.removeValue(forKey: display)
            }
        }

        if savedStates.isEmpty {
            restoreTimer?.invalidate()
            restoreTimer = nil
        } else if restoreTimer == nil {
            // A sleeping or temporarily unavailable panel may reject the first
            // restore. Keep its original values and retry when it is available.
            NSLog("ScreenDimmer: backlight restoration pending; retrying")
            restoreTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.restore()
            }
        }
    }

    deinit {
        restoreTimer?.invalidate()
    }
}
