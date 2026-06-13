import Foundation

public enum AppIdentity {
    public static let name = "GreenRAM"
    public static let bundleIdentifier = "milu.greenram"
    public static let releaseRepositoryOwner = "lwj1994"
    public static let releaseRepositoryName = "greenram"
    public static let releaseTeamIdentifier = "66NB8SX5ZT"
    public static let legacyBundleIdentifiers = [
        "dev.dontbesilent.GreenRAM",
        "dev.dontbesilent.MacAotoKill"
    ]
    public static var ownBundleIdentifiers: Set<String> {
        Set([bundleIdentifier] + legacyBundleIdentifiers)
    }

    public static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0.0.0"
    }

    public static func isOwnBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            return false
        }
        return ownBundleIdentifiers.contains(bundleIdentifier)
    }
}

public enum AppDefaults {
    private static let migrationMarkerKey = "didMigrateFromMacAotoKill"

    public static func make() -> UserDefaults {
        let defaults = UserDefaults(suiteName: AppIdentity.bundleIdentifier) ?? .standard
        migrateLegacyDefaultsIfNeeded(to: defaults)
        return defaults
    }

    private static func migrateLegacyDefaultsIfNeeded(to defaults: UserDefaults) {
        guard defaults.object(forKey: migrationMarkerKey) == nil else { return }
        let currentDomain = defaults.persistentDomain(forName: AppIdentity.bundleIdentifier) ?? [:]

        if currentDomain.isEmpty {
            for legacyBundleIdentifier in AppIdentity.legacyBundleIdentifiers {
                guard let legacyDefaults = UserDefaults(suiteName: legacyBundleIdentifier),
                      let legacyDomain = legacyDefaults.persistentDomain(forName: legacyBundleIdentifier),
                      !legacyDomain.isEmpty else { continue }

                defaults.setPersistentDomain(legacyDomain, forName: AppIdentity.bundleIdentifier)
                break
            }
        }

        defaults.set(true, forKey: migrationMarkerKey)
    }
}
