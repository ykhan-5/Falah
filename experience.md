# Falah — Experience Log

A running log of what we did, why, what broke, and what we learned. Each entry is like a commit, but it holds notes instead of code: newest on top, one entry per meaningful step. It's kept up to date as we work so anyone (or any future session) can pick up the context.

**Format:** `## <date> · <short title>`, then **Did**, **Decisions**, **Snags**, **Next**. Leave out any section that's empty.

---

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
