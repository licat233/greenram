import Foundation

public struct AppUpdateInfo: Equatable {
    public let currentVersion: String
    public let latestVersion: String
    public let releasePageURL: URL
    public let downloadURL: URL
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

        let downloadURL = Self.preferredDownloadURL(from: release.assets) ?? release.htmlURL
        return .updateAvailable(
            AppUpdateInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                releasePageURL: release.htmlURL,
                downloadURL: downloadURL
            )
        )
    }

    private static func preferredDownloadURL(from assets: [GitHubReleaseAsset]) -> URL? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }?.browserDownloadURL
            ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }?.browserDownloadURL
            ?? assets.first?.browserDownloadURL
    }
}

struct AppReleaseVersion: Comparable, Equatable {
    private let components: [Int]

    init(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")

        self.components = normalized
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    static func == (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    static func < (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
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

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
