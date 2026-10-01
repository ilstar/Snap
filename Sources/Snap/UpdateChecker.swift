import AppKit
import SnapCore

/// Compares the running version with the latest GitHub release and offers its download page.
final class UpdateChecker {
    static let releasesURL = URL(string: "https://github.com/ilstar/Snap/releases")!
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/ilstar/Snap/releases/latest")!
    private var task: Task<Void, Never>?

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name", htmlURL = "html_url", draft, prerelease
        }
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
                self?.present(release)
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

    @MainActor private func present(_ release: Release) {
        let current = Self.currentVersion
        guard !release.draft, !release.prerelease,
              let latest = AppVersion(release.tagName), let running = AppVersion(current), running < latest else {
            Self.showAlert(title: "Snap is up to date", text: "You’re running Snap \(current), the latest version.",
                           actions: ["OK"]) { _ in }
            return
        }
        Self.showAlert(title: "Snap \(latest) is available",
                       text: "You’re running Snap \(current). Download the new version from GitHub, quit Snap, and replace the app in your Applications folder.",
                       actions: ["Download", "Later"]) { if $0 == 0 { NSWorkspace.shared.open(release.htmlURL) } }
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
