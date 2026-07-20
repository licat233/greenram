import XCTest
@testable import MacAotoKillCore

final class MemoryHealthEvaluatorTests: XCTestCase {
    func testHealthyBelowWarningEntryRatio() {
        let evaluation = evaluate(ramUsed: 71, ramLimit: 90, swapUsed: 1_000, swapLimit: 2_000)

        XCTAssertEqual(evaluation.level, .healthy)
        XCTAssertTrue(evaluation.reasons.isEmpty)
    }

    func testRamWarningStartsAtEightyPercentOfConfiguredLimit() {
        let evaluation = evaluate(ramUsed: 72, ramLimit: 90)

        XCTAssertEqual(evaluation.level, .warning)
        XCTAssertEqual(evaluation.ramLevel, .warning)
        XCTAssertEqual(evaluation.reasons, [.ramApproachingLimit])
    }

    func testRamLimitProducesCriticalState() {
        let evaluation = evaluate(ramUsed: 90, ramLimit: 90)

        XCTAssertEqual(evaluation.level, .critical)
        XCTAssertEqual(evaluation.reasons, [.ramLimitReached])
    }

    func testSwapWarningOnlyParticipatesWhenLimitIsEnabled() {
        let enabled = evaluate(ramUsed: 50, ramLimit: 90, swapUsed: 1_600, swapLimit: 2_000)
        let disabled = evaluate(
            ramUsed: 50,
            ramLimit: 90,
            swapUsed: 2_000,
            swapLimit: 2_000,
            swapEnabled: false
        )

        XCTAssertEqual(enabled.swapLevel, .warning)
        XCTAssertEqual(disabled.swapLevel, .healthy)
    }

    func testNativePressureParticipatesInHighestSeverity() {
        let warning = evaluate(ramUsed: 50, ramLimit: 90, pressure: .warning)
        let critical = evaluate(ramUsed: 50, ramLimit: 90, pressure: .critical)

        XCTAssertEqual(warning.level, .warning)
        XCTAssertEqual(warning.reasons, [.systemPressure(.warning)])
        XCTAssertEqual(critical.level, .critical)
        XCTAssertEqual(critical.reasons, [.systemPressure(.critical)])
    }

    func testHighestComponentSeverityWins() {
        let evaluation = evaluate(
            ramUsed: 72,
            ramLimit: 90,
            swapUsed: 2_000,
            swapLimit: 2_000
        )

        XCTAssertEqual(evaluation.ramLevel, .warning)
        XCTAssertEqual(evaluation.swapLevel, .critical)
        XCTAssertEqual(evaluation.level, .critical)
    }

    func testWarningUsesRecoveryThresholdToAvoidFlicker() {
        let warning = evaluate(ramUsed: 72, ramLimit: 90)
        let stillWarning = evaluate(ramUsed: 68, ramLimit: 90, previous: warning)
        let recovered = evaluate(ramUsed: 67, ramLimit: 90, previous: stillWarning)

        XCTAssertEqual(stillWarning.level, .warning)
        XCTAssertEqual(recovered.level, .healthy)
    }

    func testCriticalUsesRecoveryThresholdToAvoidFlicker() {
        let critical = evaluate(ramUsed: 90, ramLimit: 90)
        let stillCritical = evaluate(ramUsed: 86, ramLimit: 90, previous: critical)
        let warning = evaluate(ramUsed: 85, ramLimit: 90, previous: stillCritical)

        XCTAssertEqual(stillCritical.level, .critical)
        XCTAssertEqual(warning.level, .warning)
    }

    private func evaluate(
        ramUsed: UInt64,
        ramLimit: Double,
        swapUsed: UInt64 = 0,
        swapLimit: UInt64 = 2_000,
        swapEnabled: Bool = true,
        pressure: MemoryPressureLevel = .normal,
        previous: MemoryHealthEvaluation? = nil
    ) -> MemoryHealthEvaluation {
        let snapshot = SystemMemorySnapshot(
            totalPhysicalBytes: 100,
            usedPhysicalBytes: ramUsed,
            freePhysicalBytes: 100 - ramUsed,
            swapTotalBytes: 8_000,
            swapUsedBytes: swapUsed,
            swapAvailableBytes: 8_000 - swapUsed
        )
        return MemoryHealthEvaluator.evaluate(
            snapshot: snapshot,
            configuration: MemoryThresholdConfiguration(
                ramLimitPercent: ramLimit,
                swapLimitEnabled: swapEnabled,
                swapLimitBytes: swapLimit
            ),
            pressure: pressure,
            previous: previous
        )
    }
}
