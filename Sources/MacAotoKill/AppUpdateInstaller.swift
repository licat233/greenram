import Foundation
import MacAotoKillCore

enum AppUpdateInstallError: LocalizedError, Equatable {
    case unsupportedAsset
    case downloadFailed(String)
    case appIsNotBundled
    case installLocationNotWritable(String)
    case extractionFailed(String)
    case noApplicationBundleFound
    case invalidDownloadedBundleIdentifier(String?)
    case invalidDownloadedVersion(String?)
    case downloadedVersionIsNotNewer(String)
    case signatureVerificationFailed(String)
    case invalidDownloadedTeamIdentifier(String?)
    case notarizationAssessmentFailed(String)
    case installerLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedAsset:
            return "The release does not include an installable GreenRAM update asset."
        case .downloadFailed(let message):
            return "The update asset could not be downloaded. \(message)"
        case .appIsNotBundled:
            return "GreenRAM is not running from an app bundle."
        case .installLocationNotWritable(let path):
            return "GreenRAM cannot replace the app at \(path). Move it to a writable location or install manually."
        case .extractionFailed(let output):
            return "The update asset could not be prepared. \(output)"
        case .noApplicationBundleFound:
            return "The update asset does not contain a macOS app bundle."
        case .invalidDownloadedBundleIdentifier(let bundleIdentifier):
            return "The downloaded app has the wrong Bundle ID: \(bundleIdentifier ?? "unknown")."
        case .invalidDownloadedVersion(let version):
            return "The downloaded app has an invalid version: \(version ?? "unknown")."
        case .downloadedVersionIsNotNewer(let version):
            return "The downloaded app is not newer than the current version: \(version)."
        case .signatureVerificationFailed(let output):
            return "The downloaded app did not pass code-signature verification. \(output)"
        case .invalidDownloadedTeamIdentifier(let teamIdentifier):
            return "The downloaded app was signed by the wrong team: \(teamIdentifier ?? "unknown")."
        case .notarizationAssessmentFailed(let output):
            return "The downloaded app did not pass Gatekeeper assessment. \(output)"
        case .installerLaunchFailed(let message):
            return "The update installer could not be started. \(message)"
        }
    }
}

struct AppUpdateInstaller {
    func prepareInstallation(for info: AppUpdateInfo) async throws -> AppUpdateInstallation {
        guard info.canInstallAutomatically else {
            throw AppUpdateInstallError.unsupportedAsset
        }

        let currentAppURL = Bundle.main.bundleURL
        guard currentAppURL.pathExtension.lowercased() == "app" else {
            throw AppUpdateInstallError.appIsNotBundled
        }
        try assertCanReplaceApp(at: currentAppURL)

        let workRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GreenRAMUpdate-\(UUID().uuidString)", isDirectory: true)
        let extractionURL = workRoot.appendingPathComponent("Extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)

        let archiveURL = workRoot.appendingPathComponent(Self.archiveFileName(for: info), isDirectory: false)
        let downloadedArchiveURL = try await downloadArchive(from: info.downloadURL)
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }
        try FileManager.default.moveItem(at: downloadedArchiveURL, to: archiveURL)

        let downloadedAppURL = try await prepareDownloadedApp(
            from: archiveURL,
            kind: info.downloadKind,
            extractionURL: extractionURL,
            workRoot: workRoot
        )
        try await validateDownloadedApp(downloadedAppURL, expectedLatestVersion: info.latestVersion)

        let installerScriptURL = workRoot.appendingPathComponent("install-greenram-update.sh", isDirectory: false)
        try writeInstallerScript(to: installerScriptURL)

        return AppUpdateInstallation(
            installerScriptURL: installerScriptURL,
            downloadedAppURL: downloadedAppURL,
            currentAppURL: currentAppURL,
            workRootURL: workRoot
        )
    }

    private func downloadArchive(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("\(AppIdentity.name)/\(AppIdentity.currentVersion)", forHTTPHeaderField: "User-Agent")
        let (fileURL, response) = try await URLSession.shared.download(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateInstallError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }
        return fileURL
    }

    private func prepareDownloadedApp(
        from archiveURL: URL,
        kind: AppUpdateDownloadKind,
        extractionURL: URL,
        workRoot: URL
    ) async throws -> URL {
        switch kind {
        case .applicationZipArchive:
            try await extractArchive(at: archiveURL, to: extractionURL)
            return try findApplicationBundle(in: extractionURL)
        case .diskImage:
            return try await copyApplicationBundleFromDiskImage(
                at: archiveURL,
                to: extractionURL,
                workRoot: workRoot
            )
        case .other:
            throw AppUpdateInstallError.unsupportedAsset
        }
    }

    private func extractArchive(at archiveURL: URL, to destinationURL: URL) async throws {
        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, destinationURL.path]
            )
        } catch let error as ProcessExecutionError {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        } catch {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        }
    }

    private func copyApplicationBundleFromDiskImage(
        at diskImageURL: URL,
        to destinationURL: URL,
        workRoot: URL
    ) async throws -> URL {
        let mountURL = workRoot.appendingPathComponent("MountedDMG", isDirectory: true)
        try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)

        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/bin/hdiutil",
                arguments: ["attach", "-nobrowse", "-readonly", "-mountpoint", mountURL.path, diskImageURL.path]
            )
        } catch let error as ProcessExecutionError {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        } catch {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        }

        do {
            let mountedAppURL = try findApplicationBundle(in: mountURL)
            let copiedAppURL = destinationURL.appendingPathComponent(mountedAppURL.lastPathComponent, isDirectory: true)
            if FileManager.default.fileExists(atPath: copiedAppURL.path) {
                try FileManager.default.removeItem(at: copiedAppURL)
            }
            try await copyApplicationBundle(from: mountedAppURL, to: copiedAppURL)
            try await detachDiskImage(at: mountURL)
            return copiedAppURL
        } catch {
            try? await detachDiskImage(at: mountURL)
            throw error
        }
    }

    private func copyApplicationBundle(from sourceURL: URL, to destinationURL: URL) async throws {
        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/bin/ditto",
                arguments: ["--noqtn", sourceURL.path, destinationURL.path]
            )
            _ = try? await Self.runProcess(
                executablePath: "/usr/bin/xattr",
                arguments: ["-dr", "com.apple.quarantine", destinationURL.path]
            )
        } catch let error as ProcessExecutionError {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        } catch {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        }
    }

    private func detachDiskImage(at mountURL: URL) async throws {
        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/bin/hdiutil",
                arguments: ["detach", mountURL.path]
            )
        } catch let error as ProcessExecutionError {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        } catch {
            throw AppUpdateInstallError.extractionFailed(error.localizedDescription)
        }
    }

    private func findApplicationBundle(in directoryURL: URL) throws -> URL {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            throw AppUpdateInstallError.noApplicationBundleFound
        }

        var fallbackAppURL: URL?
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "app" else { continue }
            enumerator.skipDescendants()
            let bundle = Bundle(url: fileURL)
            if bundle?.bundleIdentifier == AppIdentity.bundleIdentifier {
                return fileURL
            }
            fallbackAppURL = fallbackAppURL ?? fileURL
        }

        if let fallbackAppURL {
            return fallbackAppURL
        }
        throw AppUpdateInstallError.noApplicationBundleFound
    }

    private func validateDownloadedApp(_ appURL: URL, expectedLatestVersion: String) async throws {
        let bundle = Bundle(url: appURL)
        let bundleIdentifier = bundle?.bundleIdentifier
        guard bundleIdentifier == AppIdentity.bundleIdentifier else {
            throw AppUpdateInstallError.invalidDownloadedBundleIdentifier(bundleIdentifier)
        }

        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version, !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppUpdateInstallError.invalidDownloadedVersion(version)
        }

        let downloadedVersion = AppReleaseVersion(version)
        guard downloadedVersion >= AppReleaseVersion(expectedLatestVersion),
              downloadedVersion > AppReleaseVersion(AppIdentity.currentVersion) else {
            throw AppUpdateInstallError.downloadedVersionIsNotNewer(version)
        }

        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", "--verbose=2", appURL.path]
            )
        } catch let error as ProcessExecutionError {
            throw AppUpdateInstallError.signatureVerificationFailed(error.localizedDescription)
        } catch {
            throw AppUpdateInstallError.signatureVerificationFailed(error.localizedDescription)
        }

        let signatureDetails: String
        do {
            signatureDetails = try await Self.runProcess(
                executablePath: "/usr/bin/codesign",
                arguments: ["-dv", "--verbose=4", appURL.path]
            )
        } catch {
            throw AppUpdateInstallError.signatureVerificationFailed(error.localizedDescription)
        }

        let teamIdentifier = Self.signatureValue(named: "TeamIdentifier", in: signatureDetails)
        guard teamIdentifier == AppIdentity.releaseTeamIdentifier else {
            throw AppUpdateInstallError.invalidDownloadedTeamIdentifier(teamIdentifier)
        }

        try await assessDownloadedAppNotarization(appURL)
    }

    private func assessDownloadedAppNotarization(_ appURL: URL) async throws {
        do {
            _ = try await Self.runProcess(
                executablePath: "/usr/sbin/spctl",
                arguments: ["--assess", "--type", "execute", "--verbose=4", appURL.path]
            )
            return
        } catch let spctlError as ProcessExecutionError {
            do {
                _ = try await Self.runProcess(
                    executablePath: "/usr/bin/syspolicy_check",
                    arguments: ["distribution", appURL.path]
                )
                return
            } catch let syspolicyError as ProcessExecutionError {
                let output = [spctlError.localizedDescription, syspolicyError.localizedDescription]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                throw AppUpdateInstallError.notarizationAssessmentFailed(output)
            } catch {
                let output = [spctlError.localizedDescription, error.localizedDescription]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                throw AppUpdateInstallError.notarizationAssessmentFailed(output)
            }
        } catch {
            throw AppUpdateInstallError.notarizationAssessmentFailed(error.localizedDescription)
        }
    }

    private func assertCanReplaceApp(at appURL: URL) throws {
        let fileManager = FileManager.default
        let parentURL = appURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentURL.path) else {
            throw AppUpdateInstallError.installLocationNotWritable(parentURL.path)
        }
    }

    private func writeInstallerScript(to scriptURL: URL) throws {
        let script = """
        #!/bin/zsh
        set -euo pipefail

        source_app="$1"
        target_app="$2"
        app_pid="$3"
        work_root="$4"
        backup_app="${target_app}.previous-update"

        while /bin/kill -0 "$app_pid" 2>/dev/null; do
            /bin/sleep 0.2
        done

        /bin/rm -rf "$backup_app"
        if [ -d "$target_app" ]; then
            /bin/mv "$target_app" "$backup_app"
        fi

        if /usr/bin/ditto "$source_app" "$target_app"; then
            /usr/bin/xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true
            /usr/bin/open "$target_app"
            /bin/rm -rf "$backup_app" "$work_root"
        else
            /bin/rm -rf "$target_app"
            if [ -d "$backup_app" ]; then
                /bin/mv "$backup_app" "$target_app"
                /usr/bin/open "$target_app" 2>/dev/null || true
            fi
            exit 1
        fi
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static func archiveFileName(for info: AppUpdateInfo) -> String {
        let fileName = info.downloadAssetName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fileName, !fileName.isEmpty {
            return (fileName as NSString).lastPathComponent
        }
        let fallback = info.downloadURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackExtension = info.downloadKind == .diskImage ? "dmg" : "zip"
        return fallback.isEmpty ? "GreenRAM-\(info.latestVersion).\(fallbackExtension)" : (fallback as NSString).lastPathComponent
    }

    private static func runProcess(executablePath: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let message = [output, errorOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard process.terminationStatus == 0 else {
                throw ProcessExecutionError(output: message)
            }
            return message
        }.value
    }

    private static func signatureValue(named name: String, in output: String) -> String? {
        let prefix = "\(name)="
        return output
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private struct ProcessExecutionError: LocalizedError {
    let output: String

    var errorDescription: String? {
        output.isEmpty ? "Command failed." : output
    }
}

struct AppUpdateInstallation {
    let installerScriptURL: URL
    let downloadedAppURL: URL
    let currentAppURL: URL
    let workRootURL: URL

    func launchInstaller() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            installerScriptURL.path,
            downloadedAppURL.path,
            currentAppURL.path,
            "\(ProcessInfo.processInfo.processIdentifier)",
            workRootURL.path
        ]

        do {
            try process.run()
        } catch {
            throw AppUpdateInstallError.installerLaunchFailed(error.localizedDescription)
        }
    }
}
