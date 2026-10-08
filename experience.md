# Falah — Experience Log

A running log of what we did, why, what broke, and what we learned. Each entry is like a commit, but it holds notes instead of code: newest on top, one entry per meaningful step. It's kept up to date as we work so anyone (or any future session) can pick up the context.

**Format:** `## <date> · <short title>`, then **Did**, **Decisions**, **Snags**, **Next**. Leave out any section that's empty.

---

## 2026-10-08 · Milestone 5: sky colours + card redesign from mockup

**Did**
- The user supplied a mockup. The card was rebuilt to match it:
  - **Header:** a small "NOW" label over the prayer name in large bold serif. On the right, "Maghrib in" over a big countdown in the prayer's accent colour.
  - **Progress bar** for the current window (prayer start → next prayer, or sunrise → Dhuhr in the morning gap), with start and end times underneath.
  - **Arc:** back to a half ellipse + a shallow dotted night curve. **Only Sunrise and Sunset are marked** (the user asked to stop marking every prayer on the hero). The traveled part is solid in the accent colour by day; the moon moves along the dotted curve at night.
  - **List:**
    - earlier prayers dimmed
    - the current row boxed and bold, showing its **range** ("4:28 – 6:59 PM", shared AM/PM dropped)
    - a **NEXT** capsule on the next prayer
    - "Last third of the night" on its own line under a divider
  - **Footer** band (darker) with location · method · Asr and a gear. The quit button was removed from the card; right-click the icon to quit.
- **Four sky gradients**, chosen by the user: dawn, day, sunset, night. All of it lives in `SkyPalette` (pure, tested):
  - dawn: Fajr → sunrise + 40 min
  - day: until Maghrib − 60 min
  - sunset: until Isha
  - night: until Fajr
  - blends smoothstep into the next sky over the last 20 min before each boundary
  - stars fade in at night (and faintly at dawn)
- `AppClock` gained `--debug-speed N` (clock seconds per real second), the "time travel" scrubber from the spec. The scheduler converts its waits with `clock.realInterval(for:)`. Example: `--debug-time 2026-10-08T05:30 --debug-speed 300` plays a day in about 5 minutes.
- 49 tests passing. New ones cover:
  - white text ≥ 4.5:1 on every sky stop, and sampled every 5 min through a whole day of blends
  - which sky is active at given times
  - blend smoothness at boundaries
  - accents ≥ 3:1 on their sky
  - time-range formatting
  - clock speed
- Screenshots checked at 06:40 (dawn / Fajr), 12:00 (day / Morning), 18:27 (sunset / Asr, which matches the mockup) and 21:00 (night / Isha).

**Decisions**
- **White text on every sky** rather than flipping between dark and light ink. With a top/bottom gradient there's a blend moment where no single ink passes 4.5:1 on both ends. So every sky is kept dark enough for white, and the "day" sky is a rich mid blue rather than pale. Tests enforce it. Because sRGB blending can't get brighter than its brighter endpoint, the blends are safe too.
- **Accents brightened** from the spec's table (e.g. Isha #2A3360 → #9AA4F0, Fajr #3D5A8A → #8EA6D8). The originals were designed for light cards and would vanish on these dark skies.
- The current row shows its range even though M2 dropped end times. The user's mockup shows it, and the progress bar needs the end anyway. The other rows stay start-only.
- The sky period is computed from the shown schedule. Its window always contains `now`, since the shown day is the current prayer's day, or the next prayer's in the morning gap.

**Deviations from the spec**
- The spec's six phase backgrounds are replaced by the user's four skies. The six accents are kept, but brightened.

## 2026-10-08 · M4 revision: 24-hour oval

**Did**
- The user wanted all the nodes on the arc, including the last third. They picked a **24-hour oval** over evenly spaced node-to-node stepping.
- `ArcView` is now a full ellipse cut by the horizon:
  - day over the top: sunrise (left) → Dhuhr → Asr → Maghrib (right)
  - night underneath: Maghrib → Isha → Last third → Fajr → back to sunrise
  - every node sits at its real time
- The sun glows on the top half; a crescent moon with a soft glow travels the bottom.
- **The line since Fajr (start of the prayer day) is solid; the rest is dashed.** At 10 AM it's solid from Fajr up past sunrise. At 3 AM it's nearly the whole loop.
- Labels sit just inside the oval, facing the centre (direction normalised in ellipse space), so they never spill past the card edges. Maghrib's label sits above the horizon line. The current prayer's label and node are bold and slightly larger.
- **Engine change:** `ArcPosition.night` is now Maghrib → **next sunrise** (it was next Fajr, held at 1 until sunrise). `DaySchedule` gained `nextSunrise` and `nightFraction(of:)`. The moon keeps moving through Fajr time.
- 41 tests passing. Screenshots checked at 10:00, 17:47, 21:00 and 03:00.

**Decisions**
- Night nodes come from the shown schedule (`schedule.nextFajr` etc.). Between Fajr and sunrise the list shows today, so the night-half labels show *tonight's* times while the moon finishes *last* night. Positions differ by about a minute, which isn't visible, and the labels stay consistent with the list.
- The arc canvas grew from 138 → 200 pt tall.

## 2026-10-08 · Milestone 4: pop-out card

**Did**
- `UI/PopoverPanel.swift` has two pieces:
  - `CardPanel`: borderless + `.nonactivatingPanel`, `level = .statusBar`, clear background, window shadow, joins all spaces.
  - `PopoverController`, which owns the open and close behaviour:
    - hover opens after 0.3 s (tracking area on the status button)
    - while a hover-opened card is visible, a 10 Hz pointer check closes it after 0.4 s outside item ∪ card ∪ corridor
    - a click opens and **pins** the card; clicking again closes it
    - a global mouse-down monitor closes on a click outside
    - a local keyDown monitor closes on Esc (keyCode 53)
- `UI/SkyCardView.swift`, the card (360 pt wide, 18 pt continuous corners):
  - header: the current prayer in large serif, or "Morning" in the sunrise→Dhuhr gap; then "Now · Maghrib in 1 hr 12 min · 6:59 PM"
  - arc
  - list of the five prayers + Last third, with phase-coloured dots and the current row highlighted
  - footer "Houston · ISNA · Asr: Standard", plus gear (placeholder until M7) and power (Quit)
  - an unavailable state
- `UI/ArcView.swift`: a SwiftUI `Canvas` reusing `ArcGeometry`:
  - traveled part solid, the rest dashed
  - Dhuhr/Asr marks with times
  - Sunrise/Maghrib labels under the horizon
  - glowing sun in the phase accent
  - at night, the day arc goes dashed and dim and a crescent moon moves on the curve below the horizon
- `UI/CardModel.swift`: an `@Observable` model updated on every scheduler refresh, plus method short names.
- Right-click (or ctrl-click) on the item shows a menu with Quit. The status item no longer has a menu attached.
- Hidden `--show-card` launch argument opens the card pinned at launch, for screenshots.
- 40 tests passing (new: long countdown, panel frame/clamping, hover corridor, `dayFraction`).

**Decisions**
- **Hover never makes the panel key, so it never takes keyboard focus.** A click makes it key without activating the app (non-activating panel), which is what lets Esc work. Clicking a hover-opened card's icon pins it rather than closing it, since people often hover and then click.
- A pointer poll instead of tracking areas for the close rule: it handles the corridor between icon and card simply, and only runs while a hover-opened card is visible (no idle cost).
- Global monitors cover mouse clicks only. A global *key* monitor would need Accessibility permission, so Esc works only once the card is key, i.e. after a click.
- Card background is `.regularMaterial` for now. The sky gradients come in M5.

**Snags**
- First pass: the "Asr 4:28 PM" label overflowed the card's right edge (anchored leading, right of the mark). At night the Sunrise/Maghrib labels collided with the moon's path below the horizon. Fixed by anchoring Asr trailing, and laying the canvas out bottom-up: labels → night depth → horizon → arc.
- `Path.subtracting` (for the crescent) needs macOS 14, which we already require.

## 2026-10-08 · M3 revision: glyph icon + AM/PM

**Did**
- User feedback: the menu bar arc was "alright" but hard to read at a glance. It's replaced by a **phase glyph**:
  - **sun** (disc + 8 rays) for Fajr / morning / Dhuhr / Asr
  - **sunset** (a bit more than half a disc above a horizon line, with a small gap) for Maghrib
  - **crescent moon** for Isha
  - a hollow ring if times are unavailable
- `Model/MenuBarGlyph.swift` holds the phase → glyph mapping (tested). `UI/MenuBarIcon.swift` draws a 16×16 pt glyph.
- **Times now include AM/PM:** "Maghrib 6:59 PM". The countdown under an hour is unchanged ("Isha in 34m").
- Screenshots confirmed all three glyphs, via `--debug-time` 17:30 / 19:30 / 21:00. 36 tests passing.

**Decisions**
- The glyph is a **true template image** (`isTemplate = true`), so macOS tints it exactly like system icons in light and dark menu bars. That gives up the colour-coded sun dot. Colour can return briefly for the M6 "prayer moment" pulse.
- The **arc moves to the pop-out card only** (M4). `ArcGeometry` and `SkyPalette` accents stay for that.
- Time format: `setLocalizedDateFormatFromTemplate("jmm")`, so it follows the locale (12-hour with AM/PM, or 24-hour). ICU puts a narrow no-break space (U+202F) before "PM", and the tests normalise it.

## 2026-10-08 · Milestone 3: live menu bar

**Did**
- New files:
  - `Model/MenuBarText.swift`: "Asr in 32m" under an hour, "Asr 4:28" otherwise.
  - `Model/ArcGeometry.swift`: ArcPosition → point on the half ellipse or the night curve.
  - `Model/SkyPalette.swift`: `RGB` + the six phase accents. Backgrounds come in M5.
  - `UI/MenuBarIcon.swift`: the 22×13 pt drawn arc, coloured sun, and crescent moon.
  - `Services/Scheduler.swift`: minute-aligned one-shot timer + wake / day / TZ / clock observers.
- `StatusItemController.update(with:)` sets the icon, text and tooltip, with a `showsText` flag for M7. The `AppDelegate` wires engine → scheduler → status item.
- 35 tests passing (text formatting, arc geometry, scheduler delay, hex).
- Screenshot confirmed the icon in the menu bar: arc + orange sun near the right end + "Maghrib 6:59".

**Decisions**
- **Not a real template image.** `isTemplate` would turn the sun dot monochrome. The icon is an `NSImage(size:flipped:drawingHandler:)` drawn with `NSColor.labelColor`, which resolves against the menu bar's appearance at draw time. It behaves like a template for the arc and moon, while the sun keeps its phase colour (with a faint outline so the pale morning blue still reads).
- Moon = `labelColor` crescent, not the phase accent: Isha navy would vanish on a dark menu bar. At night the moon goes right → left on a shallow curve below the horizon (west → under → east).
- Countdown rounds **up** ("in 1m" until the moment). At 59m01s or more it shows the time. The time omits AM/PM: the locale's `jmm` pattern with the `a` stripped, so 24-hour locales get "18:59".
- Timer: a one-shot `Timer` re-armed after every tick, on `.common` run-loop mode, tolerance 0.2 s. It fires 50 ms *after* the minute boundary of the **app clock** (so `--debug-time` ticks on fake minutes too). Prayer times are whole minutes, so minute ticks land exactly on prayer starts. No per-second timer.
- On `NSSystemTimeZoneDidChange`, call `NSTimeZone.resetSystemTimeZone()` before recomputing, and set `engine.timeZone = .current` on every refresh.
- Monospaced-digit font for the title so the item doesn't jiggle.
- Every refresh logs at `.notice` with its reason (`start`/`minute`/`wake`/`dayChanged`/`timeZoneChanged`/`clockChanged`). `.info` isn't persisted by `log show`, so ticks were invisible at that level.

**Snags**
- `Date.FormatStyle.hour(.defaultDigits(amPM: .omitted))` gives "04:28", zero-padded. Switched to `DateFormatter.dateFormat(fromTemplate: "jmm")` minus the `a`.
- `screencapture` needed Screen Recording permission for the terminal/VS Code. With it, `screencapture -x -R<x>,0,700,24` grabs the right side of the menu bar for visual checks.
- macOS has no `timeout` command, and foreground `sleep` is blocked in this harness. Use background commands for timed checks.

## 2026-10-08 · M2 revision: Standard Asr, start times only, last third

**Did**
- Default Asr is now **Standard** (the user isn't Hanafi). Houston Oct 8 Asr is 4:28 PM; Hanafi stays a setting (5:19 PM).
- **Removed end times from the product for the MVP.** The UI shows start times only. The `IshaEnd` setting (midnight vs Fajr) is gone, since it only existed to display an end.
- Added **last third of the night**, `DaySchedule.lastThird`, from Adhan's `SunnahTimes.lastThirdOfTheNight`. Houston Oct 8 → 2:29 AM Oct 9.
- Tests updated, 26 passing.

**Decisions**
- The engine still keeps windows internally to decide "current prayer": Fajr→sunrise, and every other prayer runs until the next one. Isha now always runs to the next Fajr. So current is nil only from sunrise to Dhuhr.
- The card's list for a day is Fajr, Dhuhr, Asr, Maghrib, Isha, Last third. After midnight the list stays on yesterday until Fajr, so tonight's last third stays visible while it's upcoming.
- The last third is informational. The menu bar countdown still targets only the five prayers.
- This departs from the spec: the "start–end range" rows (Features §2) and "Isha end" (Settings §5) are dropped for v1.

## 2026-10-08 · Milestone 2: PrayerEngine

**Did**
- Added Adhan Swift 1.5.0 (pinned in `Package.resolved`).
- `Model/PrayerEngine.swift` has types for:
  - prayers and settings: `PrayerName`, `IshaEnd`, `PrayerSettings`
  - schedules: `PrayerInterval`, `DaySchedule`, `PrayerSnapshot`
  - sky and arc: `SkyPhase` (the spec's six sky phases), `ArcPosition`
- The engine's main calls are `schedule(for:)` and `snapshot(at:)`.
- 22 engine tests (34 cases with the parameterised ones) + 5 Clock tests, all passing. They cover:
  - Houston fixtures
  - both Asr methods
  - Isha end (midnight vs Fajr)
  - offsets and clamping
  - every method gives ordered times
  - DST end (Nov 1) and start (Mar 8)
  - boundary minutes
  - after-Isha → tomorrow's Fajr
  - phases, arc fractions
  - polar-day failure
- The app logs today's list + current/next/phase/arc at launch (Houston, hardcoded until M7).

**Decisions**
- **Defaults: ISNA + Hanafi Asr + Isha ends at midnight.** Hanafi matches the spec's footer mockup ("Asr: Hanafi"). Midnight comes first in the spec's Isha-end setting. All of these become settings in M7.
- `snapshot(at:)` builds schedules for **yesterday, today and tomorrow** and searches their intervals. This handles every edge without special cases:
  - before Fajr, "current" can be yesterday's Isha (when Isha ends at Fajr)
  - after Isha, "next" is tomorrow's Fajr
  - the DST night just works because everything is an absolute `Date`
- "Current prayer" can be nil: from sunrise → Dhuhr, and after Isha's midnight end until Fajr. `SkyPhase` always has a value (`morning`, `isha`), so the card can always be colored and titled.
- Which day's list the card shows: the current prayer's day, or else the next prayer's day. So at 1 AM with a midnight end, the list already shows the new day.
- Arc: `.day(f)` is sunrise→Maghrib. `.night(f)` is Maghrib→next Fajr, per the spec, and **holds at 1 from Fajr to sunrise**. Revisit in M3 if the moon looks stuck for that ~65 min.
- Offsets go through Adhan's `PrayerAdjustments`, clamped to −10…+10. Times use Adhan's default rounding to the nearest minute.
- `PrayerSettings.selectableMethods` leaves out Adhan's `.other`, a blank template with zero angles that would produce nonsense times.

**Snags**
- Swift local-name shadowing: a local `let schedule = …` declared later in the function made the earlier call to `schedule(for:)` a "circular reference". The error points at the wrong line.
- Parameterised `@Test(arguments:)` with Adhan's non-Sendable enums causes Swift 6 warnings. Passing raw-value strings avoids them.
- Fixture values were generated by Adhan, then sanity-checked (sunrise 7:19, sunset ~6:58 CDT for Houston on Oct 8). They aren't from an independent source yet. **TODO before shipping: compare a week against the masjid's printed schedule** (spec "Accuracy check").

**Next**
- M3: arc icon + "Asr in 32m" text, minute-aligned timer, wake / midnight / TZ / clock change handling.
- Countdown rounding: the log truncates ("in 31 min" at 4:47:xx for 5:19). The menu bar text should round up, so it reads 32m.

## 2026-10-08 · Milestone 1 built, tested, launched

**Did**
- Clean CLT 26.6 reinstall fixed the dyld crash.
- `scripts/test.sh` → 5 Clock tests pass.
- `scripts/build-app.sh` → signed `build/Falah.app`.
- Launched: the log shows `Falah launched`. `lsappinfo` reports `UIElement`, so there's no Dock icon. `--debug-time "2026-10-08T16:29:00"` logs `now = Oct 8, 2026 at 4:29:00 PM`.

**Decisions**
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. CLT 26.6 ships no XCTest at all, only `Testing.framework`.
- `Package.swift` is now `swift-tools-version:6.0` with `swiftLanguageModes: [.v5]`.
- **Run tests with `scripts/test.sh`, not bare `swift test`.**

**Snags**
- CLT-only SwiftPM can't find `Testing.framework`. `xcrun --show-sdk-platform-path` fails without Xcode, so the `-F /Library/Developer/CommandLineTools/Library/Developer/Frameworks` path is never added.
- Per-target `unsafeFlags` in Package.swift aren't enough. SwiftPM generates a separate runner module (`.build/debug/FalahPackageTests.derived/runner.swift`) wrapped in `#if canImport(Testing)`. That module doesn't get the test target's flags, so it compiles to a no-op: **0 tests run, exit 0, no message**. The flags have to be global (`-Xswiftc -F ...` on the command line). `test.sh` passes them and also fails if no tests ran.
- Bare `swift test` now fails loudly with "no such module 'Testing'", which is better than a silent pass.
- With CLT gone, `softwareupdate -i "Command Line Tools ..."` said "No such update" until `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress` existed. That flag file is what makes the CLT labels show up in the catalog.
- zsh has a `log` builtin. Use `/usr/bin/log show ...` to read the app's logs.
- Swift 6 compiler: string interpolation in `Logger` calls is an autoclosure, so properties need an explicit `self.`.

**Next**
- User checks the menu bar → commit M1 → M2 (Adhan + PrayerEngine).

## 2026-10-08 · Toolchain: CLT 26.6 install came out mixed

**Did**
- Updated the Command Line Tools from 15.1 to 26.6 (Swift 6.3.3).

**Snags**
- `swift build` / `swift test` crash in dyld: `Symbol not found ... BuildServerProtocol ... encodeToLSPAny`.
- Cause: a mixed install. `swift-package` is dated Jun 8, but `usr/lib/swift/pm/BuildServerProtocol.framework` is dated Sep 1. Probably two installs overlapped: running `swift --version` with no tools present opens Apple's GUI install dialog, and `softwareupdate` was running at the same time.
- Lesson: with the CLT removed, don't run any developer tool (`swift`, `git`, `clang`), because each one opens the GUI installer. Do one clean install at a time.

**Next**
- Clean reinstall: `sudo rm -rf /Library/Developer/CommandLineTools && sudo softwareupdate -i "Command Line Tools for Xcode 26.6-26.6"`.

## 2026-10-08 · Milestone 1 code written (not yet built)

**Did**
- Wrote the Swift Package skeleton:
  - `Package.swift` (tools 5.9, macOS 14, executable `Falah` + `FalahTests`)
  - `AppDelegate` (`@main`, `.accessory` policy)
  - `StatusItemController` (static "Falah" text + temporary Quit menu)
  - `AppClock` with `--debug-time`
  - `Log` (os.Logger, subsystem `com.yusufkhan.falah`)
  - `Info.plist` with `LSUIElement`
  - `scripts/build-app.sh` (release build → `.app` → ad hoc codesign + verify)
  - `ClockTests`

**Decisions**
- Bundle ID and log subsystem: `com.yusufkhan.falah`.
- The `swift-tools-version:5.9` manifest keeps Swift 5 language mode under the Swift 6 compiler, so strict-concurrency errors don't slow down v1.
- `--debug-time` sets an *offset*, not a frozen time: the fake clock keeps ticking, so a prayer moment can be watched as it arrives. It's parsed as local wall-clock time, with seconds optional. Bad input falls back to the real clock.
- One executable target (matching the spec layout). Tests use `@testable import Falah`, which works for executables on macOS.
- Temporary Quit menu on the status item, since there's no Dock icon. It goes away when the hover panel lands in M4.
- `build-app.sh` builds native-arch only for speed. The universal (arm64 + x86_64) build happens in `make-release.sh` at M8, using per-arch `--triple` builds + `lipo`, because CLT has no xcbuild for `--arch` multi-arch.

**Snags**
- The original CLT 15.1 (Swift 5.9.2) had no XCTest, so `swift test` was impossible. We decided to update the CLT instead of hand-rolling a test runner.

## 2026-10-08 · Kickoff

**Did**
- Read `Spec.md`. Agreed to work milestone by milestone, with a check-in and commit after each.

**Ideas parked**
- **Liquid glass look:** https://github.com/Glass-HQ/liquid-glass. Try it on a separate branch once the pop-out card exists (after M4/M5) and compare it against the sky-tinted card.
- `gh` isn't installed. We need `brew install gh && gh auth login` before M8.
