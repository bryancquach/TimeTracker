# TimeTracker

A lightweight macOS menu bar app for tracking time across work categories. Clicking the menu bar item opens a popover with label buttons, elapsed times, session controls, and a settings panel.

## Key features

* Each timer has a customizeable label.
* Two sets of timer types:
    1. "Timesheet" timers: can only run one at a time. Contributes to a daily total.
        * Elapsed hours accumulate per label throughout the day and auto-reset at midnight local time.
        * Elapsed hours can be modified manually in case you forget to start or stop a timer at the right moment.
        * Timers persist across app restarts within a given day, and totals are exported to a JSON file at the end of each day.
    1. Independent timers: can run multiple at a time. No impact on daily total, but can be linked to auto-start a timesheet timer when activated.
* A timesheet summary view that shows your per-label raw and adjusted hours, seven days at a time, as a table.

## Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Swift 6.0+ toolchain (included with Xcode 16+ or Command Line Tools)

You can install the full Xcode IDE from the App Store. Command Line Tools can be installed via the terminal with

```sh
xcode-select --install
```

### Build and run

**Option A — Swift Package Manager (no Xcode.app required):**

```bash
# Build release binary and wrap it in an app bundle
# Call from package root directory
./build-app.sh

# Launch
open TimeTracker.app
```

**Option B — Xcode project:**

If you have Xcode installed, regenerate the project and open it:

```bash
# Requires xcodegen (brew install xcodegen)
xcodegen generate
open TimeTracker.xcodeproj
```

Then build and run the `TimeTracker` scheme (Cmd+R).

### Data locations

By default, data is stored under `~/Library/Application Support/TimeTracker/`. To use a custom directory, create a config file at `~/.config/timetracker/config.json`:

```json
{
  "timesheetDir": "/path/to/your/data"
}
```

The app resolves the base directory in this order:
1. `~/.config/timetracker/config.json` (`timesheetDir` key)
2. `TIMESHEET_DIR` environment variable
3. `~/Library/Application Support/TimeTracker/` (default)

| File | Path |
|------|------|
| Active session | `<base>/session.json` |
| Custom labels | `<base>/labels.json` |
| Independent labels | `<base>/independent_labels.json` |
| Session logs | `<base>/logs/<YYYY-MM-DD>.json` |

The log output directory can also be overridden at runtime via the Settings panel (stored in UserDefaults).

----

# Developer notes

## Architecture

```
TimeTracker/
├── TimeTrackerApp.swift              # @main entry point; MenuBarExtra scene (.window style)
├── Constants.swift                   # AppConstants: work-day hours, persist interval, limits, keys
├── Models/
│   ├── TimerLabel.swift              # Label struct with defaults and ID generation for custom labels
│   ├── TimerSession.swift            # Per-label accumulated seconds, active timer state, day string,
│   │                                 #   independent timer, date helpers
│   └── SessionLog.swift              # Snapshot written by "Log session" (includes adjustedHours,
│                                     #   independentTimerHours); recalculation support
├── Protocols/
│   └── SessionPersisting.swift       # Protocol for persistence (enables test doubles)
├── ViewModels/
│   └── TimerViewModel.swift          # Core logic: tap handling, day rollover, sleep/wake, log
│                                     #   session, reset, label CRUD, manual time adjustment,
│                                     #   independent timer, custom log directory, recalculation
├── Views/
│   ├── PopoverContentView.swift      # Popover layout — label rows, independent timer, session controls,
│   │                                 #   settings toggle, recalculate panel
│   ├── LabelButtonView.swift         # Single row: status dot, label name, +/− buttons, elapsed hours
│   ├── SessionActionsView.swift      # "Log session" (default or custom path), "Update Past Entry",
│   │                                 #   and "Reset" with confirmation dialogs
│   ├── LabelManagerView.swift        # Floating window for adding, renaming, and deleting labels
│   └── SettingsView.swift            # Time increment amount, custom log directory, manage labels
├── Services/
│   ├── PersistenceService.swift      # JSON read/write; resolves base dir from
│   │                                 #   ~/.config/timetracker/config.json, env var, or App Support
│   ├── SleepWakeService.swift        # NSWorkspace sleep/wake + screen sleep/wake observer
│   ├── SessionLogger.swift           # Builds SessionLog from session, writes logs, recalculates
│   │                                 #   adjusted hours in existing log files
│   └── TickScheduler.swift           # 1-second tick + configurable persist-cycle callback
├── Tests/
│   ├── PersistenceServiceTests.swift
│   ├── SessionLoggerTests.swift
│   ├── SessionLogTests.swift
│   ├── TimerLabelTests.swift
│   ├── TimerSessionTests.swift
│   └── TimerViewModelTests.swift
└── Resources/
    └── Assets.xcassets               # App icon asset catalog
```

## Data flow

1. `TimeTrackerApp` creates `TimerViewModel` as `@State` and passes it to `PopoverContentView`.
2. `TimerViewModel` loads persisted labels (or defaults) and session state on init, wires up `TickScheduler`, and registers sleep/wake and termination observers.
3. `TickScheduler` fires a 1-second tick (updating `currentDate` for live display via `@Observable`) and a 60-second persist cycle that flushes accumulated time and checks for day rollover.
4. Button taps call `tap(_:)` on the view model, which flushes the current timer and toggles/switches the active label. Each label row also has +/− buttons for manual time adjustment.
5. A separate independent timer runs concurrently with the main timer. Its accumulated time is tracked independently and excluded from the adjusted-hours calculation.
6. `SleepWakeService` consolidates four NSWorkspace notifications into two callbacks. On sleep both timers are paused; on wake they resume (accounting for day rollover at midnight).
7. "Log session" delegates to `SessionLogger`, which snapshots accumulated times into a `SessionLog` (with `adjustedHours` normalized to an 8-hour day and `independentTimerHours`) and writes it to the logs directory. Logs can be saved to a custom path via an NSSavePanel.
8. "Update Past Entry" opens an existing log file and recalculates its `adjustedHours` in place.
9. Labels are user-configurable: the Settings panel opens a `LabelManagerView` window for adding, renaming, and deleting labels. Custom labels are persisted to `labels.json`.

## Running tests

```bash
# From the top-level directory of the project
swift test
```

This runs the `TimeTrackerTests` target via Swift Package Manager using the [swift-testing](https://github.com/swiftlang/swift-testing) framework. No additional setup is required — SPM resolves the test dependency automatically.

If you're using Xcode, you can also run tests with Cmd+U after generating the project (`xcodegen generate`).

## Runtime dependencies

None. The app uses only frameworks included with macOS:

- **SwiftUI** — UI and `MenuBarExtra` scene
- **AppKit** (`NSWorkspace`) — sleep/wake notifications, app termination
- **Foundation** — JSON coding, file I/O, timers

## Build-time dependencies

| Dependency | Purpose | Install |
|------------|---------|---------|
| Swift 6.0+ toolchain | Compiler and SPM | Included with Xcode 16+ or Command Line Tools |
| [swift-testing](https://github.com/swiftlang/swift-testing) | Test framework (test target only) | Resolved automatically via SPM |
| xcodegen (optional) | Generate `.xcodeproj` from `project.yml` | `brew install xcodegen` |
