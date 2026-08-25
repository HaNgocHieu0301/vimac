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

This particular checkout is an actively-maintained personal fork being revived from the original,
long-abandoned (since 2021) codebase to run on current Xcode/macOS. **See `ROADMAP.md` for the full
history of what was broken and fixed, what's still open, and hard-won gotchas** (e.g. macOS
Ventura+ renamed "System Preferences" to "System Settings", breaking the old AppleScript-based
Accessibility permission re-grant; BSD `sed` on macOS silently ignores `\b` word-boundary patterns;
RxSwift 6's `SingleEvent` changed from a custom enum to `Result<Element, Error>`). Keep that file up
to date whenever you touch build config, dependencies, or Accessibility-traversal behavior.

## Build & run

All dependencies are Swift Package Manager (no CocoaPods, no Carthage). There is no CLI test runner
script — use Xcode (`xcodebuild`) or the Xcode GUI.

```
open Vimac.xcworkspace   # Xcode resolves/fetches SPM packages automatically
```

Requires Xcode 15+ and **macOS 13+** (the app's own `MACOSX_DEPLOYMENT_TARGET`, driven by the
`LaunchAtLogin-Modern` package's `SMAppService` requirement).

One-time setup before the app actually works when run from Xcode:
- In Signing & Capabilities, set **Team** to your own Apple ID/personal team (the checked-in project
  is configured for the maintainer's team and won't have a matching cert on a fresh machine).
- Add Vimac (and Xcode, if desired) to **System Settings > Privacy & Security > Accessibility**
  manually. There is no working automatic re-grant: `grant-accessibility-permission-dev.scpt`
  targeted the classic "System Preferences" UI via AppleScript UI-scripting, which broke when Apple
  redesigned that pane into System Settings (Ventura+). Its Run Script build phase is now non-fatal
  (logs a warning instead of failing the build) but doesn't do anything useful anymore.

### Tests

Test targets: `ViMac-SwiftTests` (unit tests, e.g. `TrieTests.swift`, `InputStateTests.swift`) and
`ViMac-SwiftUITests` (UI tests). Run via Xcode's Test navigator or `xcodebuild test` against the
`Vimac` scheme in `Vimac.xcworkspace`.

## Architecture

### Startup and mode lifecycle

- `AppDelegate` bootstraps the app: sets up preferences windows and the status bar item, then
  waits for/polls Accessibility (AX) permission (`AXIsProcessTrusted()`) before calling
  `onAXPermissionGranted()`, which constructs the `ModeCoordinator` and wires up global observables.
  (Sparkle auto-update and Segment analytics were both removed during the revival — see
  `ROADMAP.md` Phase 0/1 — so don't expect to find them.)
- `ModeCoordinator` is the central dispatcher. It owns the single active `ModeController` at any time,
  listens for mode-activation triggers (global keyboard shortcuts via `VimacShortcuts`, a
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

- `Element` wraps a raw `AXUIElement` (via the AXSwift package) plus cached frame/role/actions — most
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
rather than introducing other concurrency primitives. The project is on **RxSwift 6** (bumped from
5 during the SPM migration): `Single`'s completion type is the standard `Result<Element, Error>`
(`.success`/`.failure`), not RxSwift 5's custom `SingleEvent` enum (`.success`/`.error`) — use
`observe(on:)` (not the deprecated `observeOn(_:)`) and `subscribe(onSuccess:onFailure:)` (not
`onError:`) in new code.

### Preferences

`Preferences/*ViewController.swift` implements each preferences pane (General, Bindings, Hint Mode,
Scroll Mode, Experimental, About) conforming to `SettingsPane` (protocol from the
[sindresorhus/Settings](https://github.com/sindresorhus/Settings) package — the renamed successor
of the old `Preferences` package/pod, matching Apple's System Preferences → System Settings rename),
registered with a `SettingsWindowController` in `AppDelegate.setupPreferences()`. Persisted settings
go through `UserDefaultsProperties`/`UserDefaultsProperty` (typed wrappers around `UserDefaults`,
several exposing an RxSwift "live" observable via `readLive()`) rather than touching `UserDefaults`
directly elsewhere.

### Key bindings

`Bindings/BindingsRepository.swift` + `BindingsConfig.swift` define the configurable key-sequence/shortcut
bindings surfaced in the Bindings preference pane; `Bindings/KeyboardShortcuts.swift` defines the
`VimacShortcuts` wrapper around the [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
package for the global hotkeys (renamed from `KeyboardShortcuts` to avoid clashing with the
package's own top-level `KeyboardShortcuts` namespace — don't reintroduce that name collision), and
`VimacKeySequenceListener`/`KeySequenceListener`/`Trie` implement the multi-keypress sequence
matching (e.g. typing "f d" to enter hint mode).
