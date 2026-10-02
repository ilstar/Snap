import AppKit
import Security
import SnapCore

/// Compares the running version with the latest GitHub release and installs it in place.
final class UpdateChecker {
    static let releasesURL = URL(string: "https://github.com/ilstar/Snap/releases")!
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/ilstar/Snap/releases/latest")!
    private var task: Task<Void, Never>?

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name", htmlURL = "html_url", draft, prerelease, assets
        }
    }

    private struct Asset: Decodable {
        let name: String
        let downloadURL: URL
        enum CodingKeys: String, CodingKey { case name, downloadURL = "browser_download_url" }
    }

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func checkForUpdates() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            defer { self?.task = nil }
            do {
                let release = try await Self.fetchLatestRelease()
                await self?.present(release)
            } catch {
                Self.showAlert(title: "Couldn’t check for updates",
                               text: "\(error.localizedDescription)\n\nYou can look for new versions on GitHub.",
                               actions: ["Open Releases", "OK"]) { if $0 == 0 { NSWorkspace.shared.open(Self.releasesURL) } }
            }
        }
    }

    private static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseAPI, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Snap/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    @MainActor private func present(_ release: Release) async {
        let current = Self.currentVersion
        guard !release.draft, !release.prerelease,
              let latest = AppVersion(release.tagName), let running = AppVersion(current), running < latest else {
            Self.showAlert(title: "Snap is up to date", text: "You’re running Snap \(current), the latest version.",
                           actions: ["OK"]) { _ in }
            return
        }
        guard let archive = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            Self.showAlert(title: "Snap \(latest) is available",
                           text: "You’re running Snap \(current). Download the new version from GitHub, quit Snap, and replace the app in your Applications folder.",
                           actions: ["Download", "Later"]) { if $0 == 0 { NSWorkspace.shared.open(release.htmlURL) } }
            return
        }
        var install = false
        Self.showAlert(title: "Snap \(latest) is available",
                       text: "You’re running Snap \(current). Snap will download the update, then relaunch.",
                       actions: ["Install and Relaunch", "Later", "Release Notes"]) {
            if $0 == 0 { install = true }
            if $0 == 2 { NSWorkspace.shared.open(release.htmlURL) }
        }
        guard install else { return }
        do {
            try await Self.install(from: archive.downloadURL, expecting: latest)
        } catch {
            Self.showAlert(title: "Couldn’t install the update",
                           text: "\(error.localizedDescription)\n\nYou can download Snap \(latest) from GitHub and replace the app manually.",
                           actions: ["Download", "OK"]) { if $0 == 0 { NSWorkspace.shared.open(release.htmlURL) } }
        }
    }

    /// Downloads and verifies the release archive, swaps it in for the running bundle, and relaunches.
    @MainActor private static func install(from archiveURL: URL, expecting version: AppVersion) async throws {
        let bundleURL = Bundle.main.bundleURL
        // Gatekeeper runs quarantined apps from a read-only randomized path; replacing that copy would not stick.
        guard !bundleURL.path.contains("/AppTranslocation/") else {
            throw UpdateError("Snap is running from a temporary location. Move Snap to your Applications folder first.")
        }
        guard FileManager.default.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path) else {
            throw UpdateError("Snap doesn’t have permission to replace itself in \(bundleURL.deletingLastPathComponent().path).")
        }
        // A replacement directory on the bundle's volume lets the final swap be an atomic rename.
        let workURL = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                  appropriateFor: bundleURL, create: true)
        defer { try? FileManager.default.removeItem(at: workURL) }

        var request = URLRequest(url: archiveURL, timeoutInterval: 60)
        request.setValue("Snap/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (downloadURL, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let zipURL = workURL.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: downloadURL, to: zipURL)

        let extractURL = workURL.appendingPathComponent("extracted")
        try await run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractURL.path])
        guard let newAppURL = try FileManager.default.contentsOfDirectory(at: extractURL, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError("The downloaded archive doesn’t contain an app.")
        }
        let newVersion = Bundle(url: newAppURL)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard newVersion.flatMap(AppVersion.init) == version else {
            throw UpdateError("The downloaded app is not Snap \(version).")
        }
        try verifySignature(of: newAppURL)

        _ = try FileManager.default.replaceItemAt(bundleURL, withItemAt: newAppURL)
        // Reopen once this process has exited, so the new copy never runs alongside the old one.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while /bin/kill -0 \"$0\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"",
                              String(ProcessInfo.processInfo.processIdentifier), bundleURL.path]
        try relaunch.run()
        NSApp.terminate(nil)
    }

    /// Accepts the new bundle only if it satisfies the running app's designated requirement (same identifier and team).
    private static func verifySignature(of appURL: URL) throws {
        var selfCode: SecCode?
        var selfStaticCode: SecStaticCode?
        var requirement: SecRequirement?
        var newCode: SecStaticCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStaticCode) == errSecSuccess, let selfStaticCode,
              SecCodeCopyDesignatedRequirement(selfStaticCode, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(appURL as CFURL, [], &newCode) == errSecSuccess, let newCode else {
            throw UpdateError("Snap couldn’t read the code signatures needed to verify the update.")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        let status = SecStaticCodeCheckValidity(newCode, flags, requirement)
        guard status == errSecSuccess else {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
            throw UpdateError("The downloaded app’s signature doesn’t match this copy of Snap (\(reason)).")
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError("\(executable) failed with status \(finished.terminationStatus)."))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    @MainActor private static func showAlert(title: String, text: String, actions: [String], completion: (Int) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        actions.forEach { alert.addButton(withTitle: $0) }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        completion(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
    }
}
