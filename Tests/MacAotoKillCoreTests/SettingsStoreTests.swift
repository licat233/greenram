import XCTest
@testable import MacAotoKillCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultMemoryPolicyMatchesMVPDefaults() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.ramLimitPercent, MemoryPolicyDefaults.ramLimitPercent)
        XCTAssertEqual(store.swapLimitEnabled, MemoryPolicyDefaults.swapLimitEnabled)
        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.swapLimitBytes)
        XCTAssertEqual(store.minimumBackgroundDuration, MemoryPolicyDefaults.minimumBackgroundDuration)
        XCTAssertEqual(store.maxAppsPerSweep, MemoryPolicyDefaults.maxAppsPerSweep)
        XCTAssertTrue(store.automaticUpdateReminderEnabled)
    }

    func testSwapLimitClampsToMinimum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.swapLimitBytes = 0

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.minimumSwapLimitBytes)
    }

    func testAutoQuitBackgroundDurationsPersistAndClampToMinimum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(30, for: "com.example.short")
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.long")

        XCTAssertEqual(store.minimumBackgroundDurationsByBundleID["com.example.short"], MemoryPolicyDefaults.minimumConfigurableBackgroundDuration)
        XCTAssertEqual(store.autoQuitBackgroundDuration(for: "com.example.long"), 45 * 60)
        XCTAssertNil(store.autoQuitBackgroundDuration(for: "com.example.default"))
    }

    func testResetMemoryPolicyDefaultsRemovesPerAppBackgroundDurations() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.long")

        store.resetMemoryPolicyDefaults()

        XCTAssertTrue(store.minimumBackgroundDurationsByBundleID.isEmpty)
    }

    func testThresholdConfigurationUsesSharedDefaults() {
        let configuration = MemoryThresholdConfiguration()

        XCTAssertEqual(configuration.ramLimitPercent, MemoryPolicyDefaults.ramLimitPercent)
        XCTAssertEqual(configuration.swapLimitEnabled, MemoryPolicyDefaults.swapLimitEnabled)
        XCTAssertEqual(configuration.swapLimitBytes, MemoryPolicyDefaults.swapLimitBytes)
    }

    func testUpdateCheckStatePersists() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_717_824_000)

        store.lastUpdateCheckAt = date
        store.lastPromptedUpdateVersion = "v0.1.9"
        store.automaticUpdateReminderEnabled = false

        XCTAssertEqual(store.lastUpdateCheckAt, date)
        XCTAssertEqual(store.lastPromptedUpdateVersion, "v0.1.9")
        XCTAssertFalse(store.automaticUpdateReminderEnabled)

        store.lastUpdateCheckAt = nil
        store.lastPromptedUpdateVersion = " "

        XCTAssertNil(store.lastUpdateCheckAt)
        XCTAssertNil(store.lastPromptedUpdateVersion)
    }
}
