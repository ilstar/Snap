# Snap

A native macOS menu bar window manager, built with SwiftUI and AppKit. Requires macOS 14 or later. No third-party dependencies.

## Install

Download the latest `Snap-<version>.dmg` from [Releases](https://github.com/ilstar/Snap/releases), open it, and drag **Snap.app** to Applications. A `Snap-<version>.zip` is also available. Release builds are signed with a Developer ID and notarized by Apple.

Choose **Check for Updates…** from the menu bar icon to compare your version with the latest GitHub release. If a newer version is available, Snap opens its download page; quit Snap and replace the app to update.

## Build and run

Tasks run through [mise](https://mise.jdx.dev):

```sh
mise run open
```

`mise run build` builds and signs `build/Snap.app`; `mise run open` builds and launches it. For an optimized local bundle, run `mise run build release`. Run tests with `mise run test`. Open `Package.swift` in Xcode to edit the project.

Quit Snap before rebuilding. The build script selects a unique Developer ID Application identity, or a unique Apple Development identity if no Developer ID is available. Set `SNAP_SIGNING_IDENTITY` to a specific certificate name or SHA-1 to select it explicitly. Keep the same identity across builds. The script fails if no identity is available or the selection is ambiguous. `SNAP_SIGNING_IDENTITY=- mise run build` explicitly opts into disposable ad-hoc builds.

## Setup

Click **Enable access** in Snap, then enable **Snap** under **System Settings → Privacy & Security → Accessibility**. macOS controls this permission; the app cannot grant it itself. Restart Snap if macOS does not recognize the permission immediately. If macOS requests Input Monitoring for movement mode, enable Snap there as well.

If Snap is enabled in Settings but still reports no access, an older build’s signing requirement may be registered. Remove that Snap entry, add the current `build/Snap.app`, and enable it again. **Already enabled in System Settings? → Show this copy in Finder** reveals the exact bundle. **Check again** refreshes permission status; returning from Settings also refreshes it immediately. Switching from an ad-hoc build to certificate signing requires this one-time reauthorization.

Closing the settings window leaves Snap running in the menu bar. Choose **Layouts & shortcuts…** to reopen it. Choose **Quit Snap** to stop the app and release all shortcuts.

## Layouts

Select a preset and drag across its grid to choose the window area. Each preset has its own 2–12 column and row grid. Add, rename, or delete layouts, and record a global shortcut. Window spacing (default 0 pt) and movement step are app-wide settings shared by all layouts. Changes are saved automatically in the app’s UserDefaults. Shortcut recording requires Control or Command; Escape cancels. Duplicate shortcuts are rejected, and unavailable registrations appear in settings.

| Action | Default shortcut |
| --- | --- |
| Left half | Control–Option–Left |
| Right half | Control–Option–Right |
| Top half | Control–Option–Up |
| Bottom half | Control–Option–Down |
| Fill screen | Control–Option–Return |
| Native full screen | Control–Option–F |
| Move window | Control–Option–M |
| Restore window | Control–Option–R |

**Fill screen** uses the current display’s usable area, excluding the menu bar and Dock, exactly; window spacing never applies to it. **Full screen** uses macOS native full screen in its own Space; exit using the window’s green button.

Global shortcuts act on the focused window. Menu actions and **Apply to last window** use the last external app while Snap’s settings are focused. On multiple displays, the display containing the largest portion of the window is used.

## Movement mode

Focus a window and press **Control–Option–M**, then use the arrow keys. Shift multiplies the movement step by four. Escape, Return, the movement shortcut again, switching apps, or 30 seconds of inactivity ends the mode. Other keys end the mode and pass through to the active app. Movement stays inside the current display’s usable area; moving windows between displays is not included in this version.

## Restore window

Press **Control–Option–R** or choose **Restore window** from the menu bar to return the active window to its original size and position. For example: place a window wherever you like, use **Fill screen**, then **Restore window** to put it back.

Snap saves a separate frame for each window before its first layout change, native full-screen action, or arrow movement. Further Snap changes keep that original frame until restoration succeeds. Restore also exits native full screen and ends movement mode. After a successful restore, the next Snap change captures a new starting frame. A failed restore retains the snapshot so you can retry. Snap reports when a window has no saved frame.

Snapshots last for the current Snap session and are discarded for closed windows and terminated apps. Existing layouts and shortcut customizations are preserved when the Restore action is added. If Control–Option–R is already assigned to another preset, Restore is added without a shortcut; record another one in settings. Apps may restrict window sizes or positions, and macOS may constrain restoration if a display has been disconnected.

## Validation and limitations

Automated tests cover grid bounds, spacing, display coordinate conversion, movement clamping, default shortcuts, preset serialization, per-window restore history, and migration of existing settings. macOS Accessibility and global keyboard behavior require a real desktop with user-granted permission. Some apps enforce minimum window sizes or do not support Accessibility window operations; Snap reports those failures. Leave native full screen before applying layouts or moving a window.

The build script uses certificate signing so the app’s designated requirement can remain stable across changed builds. An ad-hoc signature identifies a particular executable hash and cannot preserve Accessibility grants after that executable changes. See Apple’s [code-signing requirements documentation](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements). Certificate-signed builds use the hardened runtime and a secure timestamp.

## Releasing

Store notarization credentials once (use an [app-specific password](https://support.apple.com/102654)):

```sh
xcrun notarytool store-credentials snap-notary --apple-id <apple-id> --team-id <team-id>
```

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`, quit Snap, then run `mise run publish`. It builds with the Developer ID identity, notarizes, staples, writes `build/Snap-<version>.zip` and `build/Snap-<version>.dmg`, and publishes both as GitHub release `v<version>`; **Check for Updates…** reads the latest release tag. `mise run release` stops before publishing.

Window operations use Apple’s [Accessibility APIs](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue); movement mode uses a [Quartz event tap](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)).
