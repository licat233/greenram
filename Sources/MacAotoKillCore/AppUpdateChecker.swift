import Foundation

public struct AppUpdateInfo: Equatable {
    public let currentVersion: String
    public let latestVersion: String
    public let releasePageURL: URL
    public let downloadURL: URL
    public let downloadAssetName: String?
    public let downloadKind: AppUpdateDownloadKind

    public var canInstallAutomatically: Bool {
        downloadKind == .applicationZipArchive
    }
}

public enum AppUpdateDownloadKind: Equatable {
    case applicationZipArchive
    case diskImage
    case other
}

public enum AppUpdateCheckResult: Equatable {
    case upToDate(currentVersion: String, latestVersion: String)
    case updateAvailable(AppUpdateInfo)
}

public enum AppUpdateCheckError: LocalizedError, Equatable {
    case invalidLatestReleaseURL
    case invalidHTTPResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidLatestReleaseURL:
            return "Invalid GitHub latest release URL."
        case .invalidHTTPResponse:
            return "GitHub returned an invalid response."
        case .httpStatus(let statusCode):
            return "GitHub release check failed with HTTP \(statusCode)."
        }
    }
}

public struct GitHubReleaseUpdateChecker: Sendable {
    private let owner: String
    private let repository: String
    private let currentVersion: String

    public init(
        owner: String = AppIdentity.releaseRepositoryOwner,
        repository: String = AppIdentity.releaseRepositoryName,
        currentVersion: String = AppIdentity.currentVersion
    ) {
        self.owner = owner
        self.repository = repository
        self.currentVersion = currentVersion
    }

    public func checkForUpdate() async throws -> AppUpdateCheckResult {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest") else {
            throw AppUpdateCheckError.invalidLatestReleaseURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppIdentity.name)/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateCheckError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateCheckError.httpStatus(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = AppReleaseVersion(currentVersion)
        let latest = AppReleaseVersion(latestVersion)

        guard latest > current else {
            return .upToDate(currentVersion: currentVersion, latestVersion: latestVersion)
        }

        let download = Self.preferredDownload(from: release.assets) ?? GitHubReleaseDownload(
            name: nil,
            url: release.htmlURL,
            kind: .other
        )
        return .updateAvailable(
            AppUpdateInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                releasePageURL: release.htmlURL,
                downloadURL: download.url,
                downloadAssetName: download.name,
                downloadKind: download.kind
            )
        )
    }

    private static func preferredDownload(from assets: [GitHubReleaseAsset]) -> GitHubReleaseDownload? {
        let downloads = assets.map {
            GitHubReleaseDownload(
                name: $0.name,
                url: $0.browserDownloadURL,
                kind: downloadKind(assetName: $0.name, url: $0.browserDownloadURL)
            )
        }

        return downloads.first { Self.isPreferredApplicationZip($0) }
            ?? downloads.first { $0.kind == .applicationZipArchive }
            ?? downloads.first { $0.kind == .diskImage }
            ?? downloads.first
    }

    private static func downloadKind(assetName: String?, url: URL) -> AppUpdateDownloadKind {
        let fileNameSource: String
        if let assetName, !assetName.isEmpty {
            fileNameSource = assetName
        } else {
            fileNameSource = url.lastPathComponent
        }
        let fileName = fileNameSource.lowercased()
        if fileName.hasSuffix(".zip") {
            return .applicationZipArchive
        }
        if fileName.hasSuffix(".dmg") {
            return .diskImage
        }
        return .other
    }

    private static func isPreferredApplicationZip(_ download: GitHubReleaseDownload) -> Bool {
        let fileName = (download.name ?? download.url.lastPathComponent).lowercased()
        return download.kind == .applicationZipArchive
            && fileName.contains("greenram")
            && fileName.hasSuffix(".app.zip")
    }
}

public struct AppReleaseVersion: Comparable, Equatable {
    private let components: [Int]

    public init(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")

        self.components = normalized
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    public static func == (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public static func < (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let lhsValue = index < lhs.components.count ? lhs.components[index] : 0
            let rhsValue = index < rhs.components.count ? rhs.components[index] : 0
            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
        }
        return false
    }
}

private struct GitHubLatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct GitHubReleaseDownload {
    let name: String?
    let url: URL
    let kind: AppUpdateDownloadKind
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
