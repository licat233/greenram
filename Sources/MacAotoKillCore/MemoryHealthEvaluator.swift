import Foundation

public enum MemoryHealthLevel: Int, Comparable, Equatable {
    case healthy = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: MemoryHealthLevel, rhs: MemoryHealthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum MemoryHealthReason: Equatable {
    case ramApproachingLimit
    case ramLimitReached
    case swapApproachingLimit
    case swapLimitReached
    case systemPressure(MemoryPressureLevel)
}

public struct MemoryHealthEvaluation: Equatable {
    public let level: MemoryHealthLevel
    public let ramLevel: MemoryHealthLevel
    public let swapLevel: MemoryHealthLevel
    public let pressureLevel: MemoryHealthLevel
    public let reasons: [MemoryHealthReason]

    public init(
        level: MemoryHealthLevel,
        ramLevel: MemoryHealthLevel,
        swapLevel: MemoryHealthLevel,
        pressureLevel: MemoryHealthLevel,
        reasons: [MemoryHealthReason]
    ) {
        self.level = level
        self.ramLevel = ramLevel
        self.swapLevel = swapLevel
        self.pressureLevel = pressureLevel
        self.reasons = reasons
    }
}

public enum MemoryHealthEvaluator {
    public static let warningEntryRatio = 0.80
    public static let warningRecoveryRatio = 0.75
    public static let criticalEntryRatio = 1.00
    public static let criticalRecoveryRatio = 0.95

    public static func evaluate(
        snapshot: SystemMemorySnapshot,
        configuration: MemoryThresholdConfiguration,
        pressure: MemoryPressureLevel,
        previous: MemoryHealthEvaluation? = nil
    ) -> MemoryHealthEvaluation {
        let ramRatio = configuration.ramLimitPercent > 0
            ? snapshot.usedPhysicalPercent / configuration.ramLimitPercent
            : 0
        let ramLevel = level(for: ramRatio, previous: previous?.ramLevel ?? .healthy)

        let swapRatio = configuration.swapLimitEnabled && configuration.swapLimitBytes > 0
            ? Double(snapshot.swapUsedBytes) / Double(configuration.swapLimitBytes)
            : 0
        let swapLevel = configuration.swapLimitEnabled
            ? level(for: swapRatio, previous: previous?.swapLevel ?? .healthy)
            : .healthy

        let pressureLevel: MemoryHealthLevel = switch pressure {
        case .normal: .healthy
        case .warning: .warning
        case .critical: .critical
        }

        var reasons: [MemoryHealthReason] = []
        switch ramLevel {
        case .healthy: break
        case .warning: reasons.append(.ramApproachingLimit)
        case .critical: reasons.append(.ramLimitReached)
        }
        switch swapLevel {
        case .healthy: break
        case .warning: reasons.append(.swapApproachingLimit)
        case .critical: reasons.append(.swapLimitReached)
        }
        if pressure != .normal {
            reasons.append(.systemPressure(pressure))
        }

        return MemoryHealthEvaluation(
            level: max(ramLevel, swapLevel, pressureLevel),
            ramLevel: ramLevel,
            swapLevel: swapLevel,
            pressureLevel: pressureLevel,
            reasons: reasons
        )
    }

    private static func level(
        for ratio: Double,
        previous: MemoryHealthLevel
    ) -> MemoryHealthLevel {
        switch previous {
        case .critical:
            if ratio >= criticalRecoveryRatio { return .critical }
            if ratio >= warningRecoveryRatio { return .warning }
            return .healthy
        case .warning:
            if ratio >= criticalEntryRatio { return .critical }
            return ratio >= warningRecoveryRatio ? .warning : .healthy
        case .healthy:
            if ratio >= criticalEntryRatio { return .critical }
            return ratio >= warningEntryRatio ? .warning : .healthy
        }
    }
}
