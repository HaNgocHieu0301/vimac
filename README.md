# Announcement

Vimac is now [Homerow](https://homerow.app). Homerow is a refined, sleeker, more performant successor of Vimac, incorporating lessons learned from it's predecessor.

# Vimac - Productive macOS keyboard-driven navigation

Vimac is a macOS productivity application that provides keyboard-driven navigation and control of the macOS Graphical User Interface (GUI).

Vimac is heavily inspired by [Vimium](https://github.com/philc/vimium/).

## Getting Started

You can download Vimac [here](https://vimacapp.com). Unzip the file and move `Vimac.app` to `Applications/`.

You can refer to the manual [here](https://vimacapp.com/manual).

## How does Vimac work?

The current Vimac workflow works like this:

1. Activate a mode (`Hold Space to activate Hint-mode` is the default)
2. Perform actions within the activated mode
3. Exit the mode, either manually or automatically when the mode's task is complete

### Hint-mode

Activating Hint-mode allows one to perform a click, double-click, or right-click on an actionable UI element

Upon activation, "hints" will be generated for each actionable element on the frontmost window:

<img src="docs/hint-mode.gif">

Simply type the assigned "hint-text" (eg. "ka") to perform a click at the location!

### Scroll-mode

Activating Scroll-mode allows one to scroll through the scrollable areas of the frontmost window.

Upon activation, a red border surrounds the active scroll area:

<img src="docs/scroll-mode.gif">

HJKL keys can be used to scroll within the scroll area.

## Building

All dependencies are managed via Swift Package Manager, so no separate dependency install step is
needed — just open the workspace and build:

```
open Vimac.xcworkspace
```

Xcode will resolve and fetch the Swift packages automatically on first open/build. Requires Xcode
15+ and macOS 13+ (see `ROADMAP.md` for why).

Set the **Team** in Signing & Capabilities to your own Apple ID/Team (the checked-in project is
configured for the maintainer's personal team and won't have a matching signing certificate on
your machine).

Add Vimac (and Xcode, if you want AppleScript-driven permission granting) to **System Settings →
Privacy & Security → Accessibility**. There is no automatic re-grant step anymore — the old
`grant-accessibility-permission-dev.scpt`, which drove the classic "System Preferences" UI via
AppleScript, stopped working once Apple redesigned that pane into System Settings (macOS Ventura+);
its build phase is now non-fatal but does nothing useful. Grant the permission manually whenever it
gets reset (e.g. after a clean build, or the first time you sign the app with a new certificate).

Avoid committing them.

## Contributing

Feel free to contribute to Vimac. Make sure to open an issue / ask to work on something first!
