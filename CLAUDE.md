# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Vimac is a macOS productivity app (Swift/Cocoa, AppKit — not SwiftUI) that provides keyboard-driven,
Vimium-inspired navigation of the macOS GUI via the Accessibility API. Note: the project README states
that active development has moved to a successor app, [Homerow](https://homerow.app); this repo is the
legacy Vimac codebase.

Two core user-facing modes:
- **Hint-mode**: overlays keyboard "hints" (e.g. "ka") on every actionable UI element of the frontmost
  window/menu bar, and performs a click/double-click/right-click when the user types the matching hint text.
- **Scroll-mode**: highlights the active scrollable area of the frontmost window and lets HJKL scroll it.

## Build & run

This is an Xcode project using CocoaPods + Carthage for dependencies. There is no CLI test runner script —
use Xcode (`xcodebuild`) or the Xcode GUI.

```
pod install
carthage build
open Vimac.xcworkspace   # always open the .xcworkspace, not the .xcodeproj
```

Additional one-time setup required before the app will actually work when run from Xcode:
- In Signing & Capabilities, enable **Disable Library Validation**.
- Add both Vimac and Xcode to **System Preferences > Security & Privacy > Accessibility**, and keep that
  System Preferences pane open/unlocked during development — `grant-accessibility-permission-dev.scpt`
  runs after each build to re-grant Vimac's Accessibility permission (lost on every clean build).
- You may need to build more than once for the AppleScript re-grant step to take effect.

After building, `git status` will typically show changes to `ViMac-Swift/ViMac_Swift.entitlements`,
`Vimac.xcodeproj/project.pbxproj`, and `grant-accessibility-permission-dev.scpt` — these are local
build/signing artifacts and should not be committed.

### Tests

Test targets: `ViMac-SwiftTests` (unit tests, e.g. `TrieTests.swift`, `InputStateTests.swift`) and
`ViMac-SwiftUITests` (UI tests). Run via Xcode's Test navigator or `xcodebuild test` against the
`Vimac` scheme in `Vimac.xcworkspace`.

## Architecture

### Startup and mode lifecycle

- `AppDelegate` bootstraps the app: sets up preferences windows, the status bar item, Sparkle
  auto-update, and Segment analytics, then waits for/polls Accessibility (AX) permission
  (`AXIsProcessTrusted()`) before calling `onAXPermissionGranted()`, which constructs the
  `ModeCoordinator` and wires up global observables.
- `ModeCoordinator` is the central dispatcher. It owns the single active `ModeController` at any time,
  listens for mode-activation triggers (global keyboard shortcuts via `KeyboardShortcuts`, a
  hold-to-activate key via `HoldKeyListener`, and multi-key sequences via `VimacKeySequenceListener`),
  and deactivates the current mode whenever the frontmost app/window changes (via `FrontmostApplicationService`).
  It also temporarily forces a specific keyboard input layout during mode activation if configured
  (`UserPreferences`/`ForceKeyboardLayout`), restoring the prior layout on deactivation.
- `ModeController` (protocol in `Modes/ModeController.swift`) defines the `activate()`/`deactivate()`
  contract and a delegate callback (`modeDeactivated`) used to notify `ModeCoordinator` when a mode
  finishes. `HintModeController` and `ScrollModeController` are the two implementations.
- Vimac refuses to activate any mode when it is itself the frontmost app (talking to its own
  accessibility server crashes it) — this guard lives in `ModeCoordinator.setHintMode`/`setScrollMode`.

### Hint-mode query pipeline (`Accessibility/HintMode/`)

Finding "hintable" elements is a multi-source, concurrent RxSwift pipeline coordinated by
`HintModeQueryService`:
- Runs several independent element queries in parallel background threads, each wrapped as an RxSwift
  `Single`/`Observable`: menu bar items (`QueryMenuBarItemsService`), menu bar extras
  (`QueryMenuBarExtrasService`), Notification Center items (`QueryNotificationCenterItemsService`), and
  the focused window's element tree (`QueryWindowService`, which recurses via `TraverseElementService`
  implementations — see `TraverseElementServiceFinder` for how the right traversal strategy is picked,
  e.g. for web-area/search-predicate-compatible elements vs. generic AX elements).
- Results are concatenated (`Utils.eagerConcat`) and zipped against generated hint label strings
  (`AlphabetHints`) to produce `Hint` values (element + assigned label).
- `HintModeController` owns the resulting `[Hint]`, renders them via `HintsViewController` inside an
  `OverlayWindowController`, and listens for local key-down events to progressively filter hints by
  typed prefix, executing the matched element's click/right-click/double-click/move action
  (`Utils.leftClickMouse` etc.) when a full match is typed.

### Accessibility layer (`Accessibility/`)

- `Element` wraps a raw `AXUIElement` (via the AXSwift pod) plus cached frame/role/actions — most
  traversal and hint logic operates on `Element`, not raw AX types.
- `AXEnhancedUserInterfaceActivator` and `AXManualAccessibilityActivator` toggle non-native accessibility
  support (VoiceOver emulation / `AXManualAccessibility`) per-frontmost-app for Chromium/Electron apps
  that don't expose AX info natively; these are driven by `UserPreferencesProperties` live observables
  in `AppDelegate.setupAXAttributeObservables()`. See `docs/state-of-non-native-support.md` for the
  history/tradeoffs behind these two options (mostly no longer needed for modern Chromium/Electron).

### Reactive style

The codebase is built around RxSwift/RxCocoa throughout (services, preference reads, keyboard/window
observables). Long-lived subscriptions are collected in `CompositeDisposable`/`DisposeBag` instances
owned by the class that needs them (`AppDelegate.compositeDisposable`, `ModeCoordinator.disposeBag`,
per-`ModeController` dispose bags) and torn down on deactivation/termination — follow this pattern
rather than introducing other concurrency primitives.

### Preferences

`Preferences/*ViewController.swift` implements each preferences pane (General, Bindings, Hint Mode,
Scroll Mode, Experimental, About) using the `Preferences` pod's pane-based window controller, registered
in `AppDelegate.setupPreferences()`. Persisted settings go through `UserDefaultsProperties`/
`UserDefaultsProperty` (typed wrappers around `UserDefaults`, several exposing an RxSwift "live" observable
via `readLive()`) rather than touching `UserDefaults` directly elsewhere.

### Key bindings

`Bindings/BindingsRepository.swift` + `BindingsConfig.swift` define the configurable key-sequence/shortcut
bindings surfaced in the Bindings preference pane; `KeyboardShortcuts.swift` wraps `MASShortcut` for the
global hotkeys, and `VimacKeySequenceListener`/`KeySequenceListener`/`Trie` implement the multi-keypress
sequence matching (e.g. typing "f d" to enter hint mode).
