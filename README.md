# ScreenDimmer

ScreenDimmer covers displays with black windows after an idle timeout while keeping the Mac awake. Configure separate AC and battery timeouts from its menu bar icon.

## MacBook Air and other displays without local dimming

Enable **Turn Off Built-in Backlight (MacBook Air)** in the menu. During blackout, ScreenDimmer saves the built-in display's brightness and automatic-brightness setting, temporarily disables automatic brightness, and sets brightness to zero. Keyboard, mouse, or trackpad activity restores the saved level and automatic setting after the initial two-second grace period.

Settings are also restored when dimming is disabled, the option is changed, the screen locks, the Mac sleeps, or the app quits normally. Automatic brightness can resume adapting to ambient light after restoration. The clock is hidden on a display whose backlight is off; external displays continue using black overlays and the existing clock setting.

Backlight control uses macOS's private DisplayServices framework, resolved at runtime. If the original settings cannot be read or the backlight cannot be changed, the app retains the black overlay and logs the failure. A failed restore is retried while the app is running. Force-quitting the app cannot run restoration; use the brightness keys if needed.

The API signatures are documented in [Lunar's DisplayServices declarations](https://github.com/alin23/Lunar/blob/master/Lunar/DDC/Lunar-Bridging-Header.h).

## Build and check

On macOS with Xcode Command Line Tools installed:

```sh
bash Tests/run.sh
bash build.sh
open build/ScreenDimmer.app
```

For hardware verification, test blackout with automatic brightness both on and off, then move the pointer or press a key and confirm that the original brightness and the System Settings automatic-brightness switch return. Repeat with the option off and with an external display attached. The fake-backend tests check setting preservation and failure handling; verifying the physical backlight requires a Mac.

## Release 1.7.0

From a terminal with GitHub CLI authenticated and Git write access to both repositories, run:

```sh
bash scripts/release.sh
```

The script commits the prepared release, pushes `v1.7.0`, waits for the macOS tests and universal build to pass, and downloads the published ZIP. It verifies the bundled version and computes SHA-256 before updating the cask in this repository and in `sopos/homebrew-screendimmer`. Rerun it to finish an interrupted tap update after the release has succeeded.
