# Snap

A native macOS menu bar window manager, built with SwiftUI and AppKit. Requires macOS 14 or later. No third-party dependencies.

## Build and run

```sh
./scripts/build.sh
open build/Snap.app
```

Open `Package.swift` in Xcode to edit the project. For an optimized local bundle, run `./scripts/build.sh release`. Run tests with `swift test`.

Quit Snap before rebuilding. The build script selects a unique Developer ID Application identity, or a unique Apple Development identity if no Developer ID is available. Set `SNAP_SIGNING_IDENTITY` to a specific certificate name or SHA-1 to select it explicitly. Keep the same identity across builds. The script fails if no identity is available or the selection is ambiguous. `SNAP_SIGNING_IDENTITY=- ./scripts/build.sh` explicitly opts into disposable ad-hoc builds.

## Setup

Click **Enable access** in Snap, then enable **Snap** under **System Settings → Privacy & Security → Accessibility**. macOS controls this permission; the app cannot grant it itself. Restart Snap if macOS does not recognize the permission immediately. If macOS requests Input Monitoring for movement mode, enable Snap there as well.

If Snap is enabled in Settings but still reports no access, an older build’s signing requirement may be registered. Remove that Snap entry, add the current `build/Snap.app`, and enable it again. **Already enabled in System Settings? → Show this copy in Finder** reveals the exact bundle. **Check again** refreshes permission status; returning from Settings also refreshes it immediately. Switching from an ad-hoc build to certificate signing requires this one-time reauthorization.

Closing the settings window leaves Snap running in the menu bar. Choose **Layouts & shortcuts…** to reopen it. Choose **Quit Snap** to stop the app and release all shortcuts.

## Layouts

Select a preset and drag across its grid to choose the window area. Each preset has its own 2–12 column and row grid. Add, rename, or delete layouts, adjust spacing, and record a global shortcut. Changes are saved automatically in the app’s UserDefaults. Shortcut recording requires Control or Command; Escape cancels. Duplicate shortcuts are rejected, and unavailable registrations appear in settings.

| Action | Default shortcut |
| --- | --- |
| Left half | Control–Option–Left |
| Right half | Control–Option–Right |
| Top half | Control–Option–Up |
| Bottom half | Control–Option–Down |
| Fill screen | Control–Option–Return |
| Native full screen | Control–Option–F |
| Move window | Control–Option–M |

**Fill screen** uses the current display’s usable area, excluding the menu bar and Dock, with configured spacing. Set spacing to zero to fill it exactly. **Full screen** uses macOS native full screen in its own Space; exit using the window’s green button.

Global shortcuts act on the focused window. Menu actions and **Apply to last window** use the last external app while Snap’s settings are focused. On multiple displays, the display containing the largest portion of the window is used.

## Movement mode

Focus a window and press **Control–Option–M**, then use the arrow keys. Shift multiplies the movement step by four. Escape, Return, the movement shortcut again, switching apps, or 30 seconds of inactivity ends the mode. Other keys end the mode and pass through to the active app. Movement stays inside the current display’s usable area; moving windows between displays is not included in this version.

## Validation and limitations

Automated tests cover grid bounds, spacing, display coordinate conversion, movement clamping, default shortcuts, and preset serialization. macOS Accessibility and global keyboard behavior require a real desktop with user-granted permission. Some apps enforce minimum window sizes or do not support Accessibility window operations; Snap reports those failures. Leave native full screen before applying layouts or moving a window.

The build script uses certificate signing so the app’s designated requirement can remain stable across changed builds. An ad-hoc signature identifies a particular executable hash and cannot preserve Accessibility grants after that executable changes. See Apple’s [code-signing requirements documentation](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements). The local bundle is not notarized; notarize the final bundle before distribution.

Window operations use Apple’s [Accessibility APIs](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue); movement mode uses a [Quartz event tap](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)).
