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
}
