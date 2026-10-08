# Falah — Build Spec

Oct 8, 2026 · @Yusuf

## Overview

Falah (Arabic for success, from the adhan's "come to success") is a native macOS menu bar app that draws the day as the sun's path and shows the five daily prayer times. Hover the small arc in the menu bar and a card drops down with the arc, today's times, and a countdown to the next prayer, tinted to match the sky.

**Goal for tonight (v1):** a working, signed-ad-hoc app on GitHub that shows correct times for your location, a live menu bar icon, the pop-out card with sky colors, and a notification at each prayer time.

**Non-goals for v1:** adhan audio, Qibla direction, Ramadan mode, dhikr counter, widgets, App Store release, notarization, localization. These go in a later version.

**Target:** macOS 14 Sonoma or later, Apple silicon and Intel. Built with Swift, AppKit and SwiftUI, as a Swift Package, in VS Code with Claude Code. No Xcode required.

## How menu bar apps are built

A menu bar app is a normal Mac app that hides its Dock icon and lives in an `NSStatusItem` (the slot in the menu bar). AppKit owns the menu bar and windows; SwiftUI draws what is inside them.

**Core pieces**

- **App shell:** `AppDelegate` with `LSUIElement = true` in `Info.plist`, so there is no Dock icon and no main window.
- **Status item:** an `NSStatusItem` whose button shows a custom-drawn arc image plus short text ("Asr in 32m"). Redrawn every minute.
- **Pop-out:** an `NSPanel` (borderless, non-activating, floating) positioned under the status item, hosting a SwiftUI view via `NSHostingView`. A panel is used instead of `NSPopover` so hover-to-open and custom styling are easy.
- **Prayer engine:** a pure Swift model that turns date + location + settings into today's times, the current and next prayer, and the sun's position on the arc. No UI code, so it is unit-testable.
- **Scheduler:** one timer that fires at the next interesting moment (next minute, next prayer, midnight) and listens for wake-from-sleep, time zone and clock changes.
- **Notifications:** `UNUserNotificationCenter` for the "It's time for Asr" alert.
- **Settings:** `UserDefaults` via `@AppStorage`, edited in a small SwiftUI settings window.

**Project layout (Swift Package, no Xcode project)**

```
Falah/
  Package.swift
  Sources/Falah/
    App/AppDelegate.swift        // status item, lifecycle, main entry
    App/StatusItemController.swift  // icon drawing, hover tracking
    UI/PopoverPanel.swift        // NSPanel positioning + show/hide
    UI/SkyCardView.swift         // SwiftUI card: arc, list, footer
    UI/ArcView.swift             // the sun path drawing
    UI/SettingsView.swift
    Model/PrayerEngine.swift     // wraps Adhan, current/next, arc position
    Model/SkyPalette.swift       // colors per phase + blending
    Model/Settings.swift
    Services/Scheduler.swift     // timers, wake, clock changes
    Services/LocationService.swift
    Services/Notifier.swift
  Resources/Info.plist
  Tests/FalahTests/             // engine + palette tests
  scripts/build-app.sh           // swift build -> wrap into .app bundle
  scripts/make-release.sh        // zip the .app for GitHub
```

**Building without Xcode:** install Apple's Command Line Tools (`xcode-select --install`). `swift build -c release` compiles the binary; `scripts/build-app.sh` copies it into a `Falah.app/Contents/MacOS/` folder with `Info.plist`, then signs it ad hoc with `codesign --sign -`. Run with `open build/Falah.app`.

## Features and UI

Everything below matches the mockup: a menu bar arc, a hover card tinted to the sky, and a gentle alert at each prayer.

**1. Menu bar item**

- A 22×13 pt arc (half ellipse over a faint horizon line) with a sun dot placed at the current position. At night the dot becomes a small moon below or along the arc.
- Text beside it: "Asr in 32m" (under 1 hour), "Asr 4:30" (over 1 hour). A setting can hide the text.
- Drawn as a template-style image so it reads in light and dark menu bars; the sun dot keeps its phase color.

**2. Pop-out card (hover or click)**

- Opens after the pointer rests on the status item for about 0.3 s; also toggles on click. Closes when the pointer leaves both the item and the card for about 0.4 s, or on click outside or Esc.
- Width 360 pt, rounded 18 pt, soft shadow, anchored under the status item and kept on screen.
- Header: current prayer name (large serif), "Now · ends 4:30 PM", and "Asr in 32 min".
- Arc: sunrise on the left, Maghrib on the right, Dhuhr at the top, Asr marked on the right side. The traveled part is drawn solid; the rest dashed. The sun glows at its current spot.
- List: Fajr, Dhuhr, Asr, Maghrib, Isha, each with a colored dot and its start–end range. The current prayer row is highlighted.
- Footer: "Houston · ISNA · Asr: Hanafi" and a Settings button.

**3. Sky colors**

| Phase | When | Card background | Accent |
| --- | --- | --- | --- |
| Fajr | Fajr → sunrise | deep blue to dusty violet | #3D5A8A |
| Morning | sunrise → Dhuhr | pale blue to soft white | #8CC0EA |
| Dhuhr | Dhuhr → Asr | bright blue to warm cream | #E0B84A |
| Asr | Asr → Maghrib | soft blue to gold | #E0902E |
| Maghrib | Maghrib → Isha | orange to rose | #D4607A |
| Isha | Isha → Fajr | navy with a few stars | #2A3360 |

Colors blend smoothly over the last 20 minutes before each boundary so there is never a hard jump. Text switches between dark and light ink to keep at least 4.5:1 contrast.

**4. Prayer-time moment**

- At each prayer start: the menu bar sun dot pulses 3 times and the icon briefly fills with the new phase color.
- If the card is open, the new prayer's row slides to the highlight and the background cross-fades.
- A system notification: "It's time for Asr · 4:30 PM". Optional reminder X minutes before (default off).
- No sound by default.

**5. Settings window**

- Location: automatic (Location Services) or typed city / coordinates.
- Calculation method (default ISNA for North America), Asr method (Standard or Hanafi), high-latitude rule.
- Per-prayer minute adjustments (−10 to +10) to match your local masjid.
- Isha end: midnight or Fajr.
- Show countdown text in menu bar; notifications on/off; launch at login.

## Prayer time calculation

Use [Adhan Swift](https://github.com/batoulapps/adhan-swift) (MIT, Swift Package Manager, `from: "1.5.0"`) instead of writing the astronomy by hand.

**How it is called**

- `Coordinates(latitude:longitude:)` for the location.
- `CalculationMethod.northAmerica.params` (ISNA) as the default, with `madhab` set to `.hanafi` or `.shafi` from settings. Other methods (Muslim World League, Umm al-Qura, Egyptian, Karachi, etc.) are listed in the library's METHODS.md.
- `PrayerTimes(coordinates:date:calculationParameters:)` with `DateComponents` holding only year, month, day for the local date. It returns an optional; handle `nil` with a clear error state in the card.
- `currentPrayer()`, `nextPrayer()` and `time(for:)` drive the header and countdown. `SunnahTimes(from:).middleOfTheNight` gives the midnight end for Isha.
- Results are absolute `Date` values. Format them with the user's current time zone.

**Start and end times shown in the list**

| Prayer | Starts | Ends |
| --- | --- | --- |
| Fajr | Fajr | Sunrise |
| Dhuhr | Dhuhr | Asr |
| Asr | Asr | Maghrib |
| Maghrib | Maghrib | Isha |
| Isha | Isha | Midnight or next Fajr (setting) |

**Arc position:** the sun's spot is the fraction of time elapsed between sunrise and Maghrib, mapped onto the half ellipse. Before sunrise and after Maghrib, the dot moves below the horizon line as a moon, using the fraction of the night from Maghrib to tomorrow's Fajr.

**Location:** ask for Location Services once ("When In Use"), cache the last coordinates, and fall back to a typed city if denied. Recompute only when the location moves more than about 10 km.

**Accuracy check:** before shipping, compare a week of output against your local masjid's printed schedule and note any fixed offset in the per-prayer adjustments.

## Pitfalls and how to handle them

The biggest risks are wrong times and a timer that drifts after sleep; the rest are polish.

| Challenge | Why it bites | How to handle it |
| --- | --- | --- |
| Wrong prayer times | Methods, madhab and high-latitude rules differ; a wrong default looks like a bug | Default ISNA + user's chosen Asr method, per-prayer offsets, and a manual check against the local masjid |
| Mac wakes from sleep with stale times | Timers pause during sleep, so the countdown and phase are wrong on wake | Listen for `NSWorkspace.didWakeNotification` and recompute everything immediately |
| Midnight rollover | After Isha, "next prayer" is tomorrow's Fajr, which today's `PrayerTimes` does not contain | Compute tomorrow's times too; switch the day at local midnight via `NSCalendarDayChanged` |
| Time zone or DST change | Travel or a DST shift moves every time | Observe `NSSystemTimeZoneDidChange` and `NSSystemClockDidChange`; recompute |
| Hover feels jumpy | Moving across the menu bar opens the card by accident | 0.3 s open delay, 0.4 s close grace period, a small hover corridor between icon and card |
| Card steals focus | A normal window would pull focus from your current app | Use a non-activating `NSPanel` (`.nonactivatingPanel`), `level = .statusBar` |
| Multiple displays / notch | The status item can be on any screen or hidden behind the notch | Position from the status button's window frame; clamp to that screen's visible frame |
| Location permission denied | No coordinates, no times | Typed city or coordinates fallback in Settings; clear message in the card |
| Notification permission | First run needs approval; ad-hoc builds may re-prompt after rebuilds | Request on first launch with a short explanation; app still works without it |
| Unsigned app warning | Not notarized, so Gatekeeper blocks first open | README tells users: System Settings → Privacy & Security → Open Anyway |
| Battery use | A per-second timer wakes the CPU all day | Update once per minute, aligned to the minute; animations only while the card is visible |
| No hot reload | Each change needs rebuild + relaunch | Keep `build-app.sh` fast; put logic in the engine so most fixes are tested with `swift test` |
| Light and dark menu bar | A colored icon can vanish on one of them | Draw the arc as a template image; only the small sun dot keeps color |

## Build plan

Build in this order; each milestone ends with something you can see or a passing test, so the app is shippable at any stop after milestone 4.

1. **Skeleton.** Swift Package, `AppDelegate`, `LSUIElement`, a status item showing static text, `build-app.sh` producing `Falah.app`.
   - Done when: `open build/Falah.app` shows text in the menu bar and no Dock icon.
2. **Prayer engine.** Add Adhan; `PrayerEngine` returns today's and tomorrow's times, current/next prayer, countdown, arc fraction.
   - Done when: `swift test` passes for a fixed date and Houston coordinates, including the after-Isha → tomorrow Fajr case.
3. **Live menu bar.** Draw the arc icon with the sun dot; text "Asr in 32m"; minute-aligned timer; wake, midnight and time zone handling.
   - Done when: changing the Mac's clock or time zone updates the icon within seconds.
4. **Pop-out card.** `NSPanel` + SwiftUI card: header, arc, list, footer; hover and click open, close rules.
   - Done when: hover opens it under the icon, moving away closes it, it never steals focus.
5. **Sky colors.** `SkyPalette` with the six phases and blending; contrast-safe text.
   - Done when: a debug "time travel" setting (hidden) can scrub through a day and the card colors change smoothly.
6. **Notifications and prayer moment.** `UNUserNotificationCenter` alerts at each prayer; icon pulse; card cross-fade.
   - Done when: with a test time 1 minute ahead, the alert and pulse fire.
7. **Settings.** Location mode, method, Asr method, offsets, Isha end, toggles, launch at login (`SMAppService`).
   - Done when: changing the Asr method moves Asr in the card immediately.
8. **Ship.** README with screenshot, MIT license, `make-release.sh`, GitHub release with the zipped `.app`.

If time runs short tonight, ship after milestone 5 and leave 6 and 7 for v1.1.

## Testing and shipping

Your Mac is the test environment: Claude Code builds, launches and checks the real app; you judge how it looks and feels.

**Automated (Claude Code runs these)**

- `swift test` for the engine: fixed dates and coordinates, current/next prayer at boundary minutes, after-Isha rollover, DST change days, each Asr method.
- Palette tests: every phase color pair meets 4.5:1 text contrast.
- Build + launch loop: `scripts/build-app.sh && open build/Falah.app`, then read logs with `log stream --predicate 'subsystem == "com.yourname.falah"'`.
- A hidden `--debug-time "2026-10-08T16:29:00"` launch argument that fakes the clock, so the Asr moment can be tested without waiting.

**Manual (you)**

- Hover feel, animation timing, colors at each phase (use the debug time argument).
- Sleep the Mac for a few minutes, wake it, confirm the countdown is right.
- Compare times with your masjid's schedule.

**Shipping to GitHub**

1. Create a public repo `falah` with README, screenshot, MIT `LICENSE`.
2. `scripts/make-release.sh` builds release, signs ad hoc, and zips `Falah.app` with `ditto -c -k --keepParent`.
3. `gh release create v1.0.0 build/Falah.zip` with notes on the Open Anyway step.
4. Later: Developer ID signing + notarization ($99/yr Apple Developer Program) removes the warning; a Homebrew cask can follow.

## Kickoff prompt for Claude Code

Export this doc as Markdown, save it as `SPEC.md` in an empty folder, open the folder in VS Code, and paste this into Claude Code:

```
Read SPEC.md. It is the full spec for Falah, a native macOS menu bar app.

Build it as a Swift Package (no Xcode project) using Swift, AppKit and SwiftUI,
targeting macOS 14+. I only have the Command Line Tools installed, not Xcode.

Work through the Build plan milestones in order. For each milestone:
1. Implement it.
2. Run `swift test` and scripts/build-app.sh, fix any errors.
3. Launch the app with `open build/Falah.app` and check the logs.
4. Tell me what to look at, wait for my OK, then move on.

Rules:
- Keep prayer logic in Model/PrayerEngine.swift with no UI code, fully unit-tested.
- Use Adhan Swift via SwiftPM for all prayer-time math.
- Use a non-activating NSPanel for the pop-out, not NSPopover.
- Update the menu bar once per minute, aligned to the minute; recompute on
  wake, midnight, time zone change and clock change.
- Add the --debug-time launch argument early so we can test prayer moments.
- Commit after each milestone with a clear message.

Start with milestone 1.
```
