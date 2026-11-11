# Changelog

## 1.7.0

- Add **Turn Off Built-in Backlight (MacBook Air)** to the menu. This optional mode saves the built-in display's brightness and automatic-brightness setting, disables automatic adjustment, and sets the backlight to zero during blackout.
- Restore both settings on activity, disable, lock, sleep, or normal quit. Retry temporary restoration failures while running.
- Hide the clock on the display whose backlight is off, keeping the existing overlays on external displays.
- Preserve activity received during the initial blackout grace period so it still dismisses the blackout afterward.
- Add backlight restoration tests and macOS build checks, including tests before publishing release assets.
