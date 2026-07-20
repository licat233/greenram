# Changelog

[Chinese version](CHANGELOG.zh-CN.md)

All notable GreenRAM release changes are recorded here.

## v0.15.0 - 2026-07-20

- Made native macOS Memory Pressure the source of the global green, orange, and red health state.
- Kept RAM and configured Swap thresholds as advisory metric colors instead of treating high utilization as system distress.
- Added a safe “Reduce Memory Pressure” action that asks for confirmation, preserves frontmost and protected apps, and requests normal app termination.
- Explicitly avoids unsupported Swap deletion or forced Swap clearing; historical Swap may remain while memory pressure is healthy.
- Retained all six UI languages.


## v0.14.0 - 2026-07-19

- Added green, orange, and red menu bar states for healthy, warning, and critical memory conditions.
- Evaluate visual health from RAM, enabled Swap limits, and native macOS memory pressure.
- Added hysteresis thresholds to prevent the status icon from flickering near warning and critical boundaries.
- Added localized health status and reason text for all six supported languages.
- Prefer the Universal 2 archive for automatic in-app updates when architecture-specific packages are also present.

## v0.13.0 - 2026-07-17

- Changed automatic cleanup to request a normal app quit instead of immediately force terminating eligible apps.
- Added macOS memory-pressure events as an ordinary-app cleanup gate alongside the existing RAM, Swap, and per-app limits.
- Added structured cleanup decisions so the menu can explain whether an app is eligible because of Auto-Quit, system memory, or its own memory limit.
- Start the duplicate-request cooldown only after macOS accepts the quit request.
- Point in-app update checks at the canonical `licat233/greenram` release repository.

## v0.12.1 - 2026-06-29

- Refined the app icon for macOS 13-15 by adding transparent padding and rounded corners to the legacy `.icns` asset.

## v0.12.0 - 2026-06-20

- Separated Auto-Quit Apps from per-app Auto-Quit thresholds. Existing custom-time rules migrate into Auto-Quit Apps once to preserve upgrade behavior.
- Changed App Rules into rule-type subpages and added per-app memory limits as an ordinary-app cleanup gate.
- Blocked protected apps from being added to Auto-Quit, timeout, or per-app memory-limit rules until they are removed from the whitelist.

## v0.11.1 - 2026-06-13

- Kept in-app automatic updates on the signed and notarized `.app.zip` release asset.
- Added DMG installation support as an automatic-update fallback when a zip asset is unavailable.
- Added a Gatekeeper assessment fallback for automatic updates when `spctl` reports a transient system error.
- Added the current GreenRAM version to Settings.
- Prevented GreenRAM from being added to cleanup rules or being targeted by cleanup.

## v0.11.0 - 2026-06-13

- Added one-click in-app updates from GitHub Releases using the signed and notarized app zip asset.
- Added automatic download, extraction, app replacement, and relaunch for installable updates.
- Hardened update validation with Bundle ID, version, code-signature, Team ID, and Gatekeeper checks before installation.
- Changed automatic update checks to run daily while GreenRAM remains open and to prompt whenever a newer version is still available.
- Prefer `GreenRAM-*.app.zip` release assets for automatic updates, with DMG/manual download as a fallback.

## v0.1.10 - 2026-06-13

- Refactored Settings into a cleaner SwiftUI and AppleViewModel structure, with app-rule management moved into a focused rules page.
- Redesigned the menu memory dashboard to reuse the Settings ring indicators, adapt its height, and show cleaner RAM and Swap labels.
- Changed the default Swap limit to 8 GB, capped configurable Swap limits at 64 GB, and migrated legacy default values.
- Force legacy RAM limit overrides back to 100% at startup.
- Simplified cleanup wording and menu labels, including "All Apps" and clearer Auto-Quit Apps explanations.

## v0.1.9 - 2026-06-08

- Added GitHub Releases update checks with a manual menu action.
- Added automatic update reminders, enabled by default and shown at most once per new version.
- Added a Settings toggle for automatic update reminders.
- Open the preferred release asset through the system, using the DMG when available.

## v0.1.8 - 2026-06-08

- Updated cleanup policy: Auto-Quit Apps only wait for their non-frontmost time; ordinary non-whitelisted apps also require RAM or Swap limits to be exceeded; whitelisted apps are never quit.
- Updated Settings and README wording to match the new cleanup policy.
- Removed the obsolete MVP notes document.

## v0.1.7 - 2026-06-08

- Set the minimum configurable background time to 3 minutes.
- Changed timeout cleanup to use an explicit Auto-Quit Apps list.
- Made the Auto-Quit Apps list and whitelist mutually exclusive.
- Renamed memory threshold UI language to status-limit language.
- Clarified that automatic cleanup does not wait for RAM or Swap limits to be exceeded.
- Clarified Auto-Quit Apps wording in Settings and README: listed apps exit once their non-frontmost time limit is met.

## v0.1.6 - 2026-06-08

- Shipped Universal 2 release packages for Apple Silicon (`arm64`) and Intel (`x86_64`) Macs.
- Added app-specific background-time overrides in Settings.
- Added policy and settings-store support for per-Bundle ID background-time thresholds.
- Updated reset behavior to remove app-specific background-time overrides.
- Added README compatibility notes and this changelog.

## v0.1.5 - 2026-06-08

- Added app-bundle picking for whitelist entries in Settings.
- Improved whitelist rows with app names, icons, and Bundle ID details.
- Cached selected app paths for whitelist display and removed cached paths when entries are removed.

## v0.1.4 - 2026-06-08

- Added whitelist management directly in Settings.
- Made default system whitelist entries editable instead of permanently protected.
- Changed duplicate quit cooldown tracking from PID to Bundle ID.

## v0.1.3 - 2026-06-08

- Changed cleanup policy to use non-frontmost duration instead of memory size as the app-level cleanup condition.
- Added a configurable background-time threshold with a 30-minute default.
- Removed app type, Bundle ID keyword, app-name keyword, and risk-classifier checks from cleanup decisions.
- Kept RAM and Swap as status/threshold display signals instead of app-level cleanup gates.

## v0.1.2 - 2026-06-08

- Updated menu wording to distinguish cleanable and non-cleanable apps.
- Added the Settings screenshot to project docs.
- Refined localization text around cleanup candidates.

## v0.1.1 - 2026-06-08

- Bumped the app version to 0.1.1.

## v0.1.0 - 2026-06-05

- First tagged GreenRAM release.
- Added menu bar memory status, Settings, whitelist support, event logging, and localized UI.
- Added multi-process memory accounting for app process trees.
