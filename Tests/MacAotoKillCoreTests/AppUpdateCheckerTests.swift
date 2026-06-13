import XCTest
@testable import MacAotoKillCore

final class AppUpdateCheckerTests: XCTestCase {
    func testReleaseVersionIgnoresLeadingV() {
        XCTAssertEqual(AppReleaseVersion("v0.1.8"), AppReleaseVersion("0.1.8"))
        XCTAssertEqual(AppReleaseVersion("V0.1.8"), AppReleaseVersion("0.1.8"))
    }

    func testReleaseVersionComparesNumericComponents() {
        XCTAssertGreaterThan(AppReleaseVersion("0.1.10"), AppReleaseVersion("0.1.9"))
        XCTAssertGreaterThan(AppReleaseVersion("1.0.0"), AppReleaseVersion("0.9.9"))
        XCTAssertEqual(AppReleaseVersion("1.0"), AppReleaseVersion("1.0.0"))
    }

    func testZipUpdateCanInstallAutomatically() {
        let info = AppUpdateInfo(
            currentVersion: "0.1.10",
            latestVersion: "0.1.11",
            releasePageURL: URL(string: "https://example.com/releases/tag/v0.1.11")!,
            downloadURL: URL(string: "https://example.com/GreenRAM-0.1.11.zip")!,
            downloadAssetName: "GreenRAM-0.1.11.zip",
            downloadKind: .applicationZipArchive
        )

        XCTAssertTrue(info.canInstallAutomatically)
    }

    func testDiskImageUpdateCannotInstallAutomatically() {
        let info = AppUpdateInfo(
            currentVersion: "0.1.10",
            latestVersion: "0.1.11",
            releasePageURL: URL(string: "https://example.com/releases/tag/v0.1.11")!,
            downloadURL: URL(string: "https://example.com/GreenRAM-0.1.11.dmg")!,
            downloadAssetName: "GreenRAM-0.1.11.dmg",
            downloadKind: .diskImage
        )

        XCTAssertFalse(info.canInstallAutomatically)
    }
}
