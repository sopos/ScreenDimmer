import Cocoa
import IOKit.pwr_mgt

class IdleMonitor: ObservableObject {
    @Published var isEnabled = true {
        didSet {
            if isEnabled {
                createAssertion()
                startMonitoring()
            } else {
                releaseAssertion()
                stopMonitoring()
                BlackoutManager.shared.hideBlackout()
            }
        }
    }

    @Published var timeoutMinutes: Int {
        didSet {
            UserDefaults.standard.set(timeoutMinutes, forKey: "timeoutMinutes")
        }
    }

    @Published var showClock: Bool {
        didSet {
            UserDefaults.standard.set(showClock, forKey: "showClock")
            BlackoutManager.shared.showClock = showClock
        }
    }

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var timer: Timer?

    static let shared = IdleMonitor()

    private init() {
        let savedTimeout = UserDefaults.standard.integer(forKey: "timeoutMinutes")
        self.timeoutMinutes = savedTimeout > 0 ? savedTimeout : 5
        self.showClock = UserDefaults.standard.bool(forKey: "showClock")

        createAssertion()
        startMonitoring()
    }

    private func createAssertion() {
        guard !hasAssertion else { return }

        let reason = "ScreenDimmer preventing screensaver" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if status == kIOReturnSuccess {
            hasAssertion = true
        }
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
    }

    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkIdle() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .init(rawValue: ~0)!
        )

        let thresholdSeconds = Double(timeoutMinutes * 60)

        if BlackoutManager.shared.isShowingBlackout {
            let gracePeriod = 2.0
            if let startTime = BlackoutManager.shared.blackoutStartTime,
               Date().timeIntervalSince(startTime) > gracePeriod,
               idleSeconds < 1.0 {
                BlackoutManager.shared.hideBlackout()
            }
        } else if idleSeconds >= thresholdSeconds && !otherAppPreventsDisplaySleep() {
            BlackoutManager.shared.showClock = showClock
            BlackoutManager.shared.showBlackout()
        }
    }

    private func otherAppPreventsDisplaySleep() -> Bool {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertionsByProcess) == kIOReturnSuccess,
              let raw = assertionsByProcess?.takeRetainedValue() as NSDictionary? else {
            return false
        }

        let myPid = ProcessInfo.processInfo.processIdentifier

        for (_, value) in raw {
            guard let assertions = value as? [[String: Any]] else { continue }
            for assertion in assertions {
                guard let type = assertion["AssertType"] as? String,
                      let pid = assertion["AssertPID"] as? Int32,
                      pid != myPid else { continue }

                if type == "PreventUserIdleDisplaySleep"
                    || type == "NoDisplaySleepAssertion" {
                    return true
                }
            }
        }
        return false
    }

    deinit {
        releaseAssertion()
        stopMonitoring()
    }
}
