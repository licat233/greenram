# GreenRAM

GreenRAM is a macOS menu bar app that watches RAM and Swap usage, then force quits cleanable apps when configured limits are exceeded.

It is built for a simple case: keep the frontmost app responsive when memory pressure gets too high.

## Screenshots

### Menu

![GreenRAM menu](docs/screenshots/menu.png)

### Settings

![GreenRAM settings window](docs/screenshots/settings.png)

## Features

- Menu bar memory status with a green/red leaf icon.
- RAM and Swap threshold settings.
- Automatic cleanable app termination when limits are exceeded.
- Manual "Clean Apps Now" action.
- Whitelist support for apps that should never be quit.
- Multi-process memory accounting for browsers, Electron apps, Xcode helpers, and similar app trees.
- Localized UI for Simplified Chinese, Traditional Chinese, English, Japanese, German, and French.

## Safety Rules

GreenRAM never quits:

- the frontmost app
- whitelisted apps
- protected system apps such as Finder, Dock, and System Settings
- apps marked as not cleanable
- small apps below the minimum memory threshold

## Download

Download the latest signed and notarized DMG from the [Releases](../../releases) page.

## Build

```sh
swift build -c release
```

Run locally:

```sh
swift run GreenRAM
```
