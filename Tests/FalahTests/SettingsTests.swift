import CoreLocation
import Foundation
import Testing
@testable import Falah

struct SettingsTests {
    /// A fresh, isolated defaults domain per test.
    func makeDefaults() -> UserDefaults {
        let name = "falah.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaults() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.locationMode == .automatic)
        #expect(store.method == .northAmerica)
        #expect(store.madhab == .shafi)
        #expect(store.highLatitudeRule == nil)
        #expect(store.adjustmentsEnabled == false)
        #expect(store.showsCountdownText)
        #expect(store.notificationsEnabled)
        #expect(store.reminderMinutes == 0)
        #expect(store.momentColorHex == "#FF9F0A")
        #expect(store.activePlace == nil)
    }

    @Test func valuesPersistAcrossLaunches() {
        let defaults = makeDefaults()
        let a = SettingsStore(defaults: defaults)
        a.locationMode = .manual
        a.manualPlace = SavedPlace(name: "London", latitude: 51.5072, longitude: -0.1276)
        a.method = .muslimWorldLeague
        a.madhab = .hanafi
        a.highLatitudeRule = .seventhOfTheNight
        a.adjustmentsEnabled = true
        a.adjustments = [.fajr: -2, .isha: 5]
        a.showsCountdownText = false
        a.notificationsEnabled = false
        a.reminderMinutes = 10
        a.momentColorHex = "#33AA77"

        let b = SettingsStore(defaults: defaults)
        #expect(b.locationMode == .manual)
        #expect(b.manualPlace == SavedPlace(name: "London", latitude: 51.5072, longitude: -0.1276))
        #expect(b.method == .muslimWorldLeague)
        #expect(b.madhab == .hanafi)
        #expect(b.highLatitudeRule == .seventhOfTheNight)
        #expect(b.adjustmentsEnabled)
        #expect(b.adjustments == [.fajr: -2, .isha: 5])
        #expect(!b.showsCountdownText)
        #expect(!b.notificationsEnabled)
        #expect(b.reminderMinutes == 10)
        #expect(b.momentColorHex == "#33AA77")
    }

    @Test func offsetsOnlyApplyWhileToggleIsOn() {
        let store = SettingsStore(defaults: makeDefaults())
        store.adjustments = [.asr: 4]
        #expect(store.prayerSettings.adjustments.isEmpty)
        store.adjustmentsEnabled = true
        #expect(store.prayerSettings.adjustments == [.asr: 4])
    }

    @Test func activePlaceFallsBackToTypedCity() {
        let store = SettingsStore(defaults: makeDefaults())
        let typed = SavedPlace(name: "Houston", latitude: 29.76, longitude: -95.37)
        let fix = SavedPlace(name: "Austin", latitude: 30.27, longitude: -97.74)
        store.manualPlace = typed
        // Automatic with no fix yet (or denied): use the typed city.
        #expect(store.activePlace == typed)
        store.autoPlace = fix
        #expect(store.activePlace == fix)
        store.locationMode = .manual
        #expect(store.activePlace == typed)
    }

    @Test func everyChangeNotifies() {
        let store = SettingsStore(defaults: makeDefaults())
        var count = 0
        store.onChange = { count += 1 }
        store.madhab = .hanafi
        store.reminderMinutes = 5
        store.autoPlace = SavedPlace(name: "X", latitude: 1, longitude: 2)
        #expect(count == 3)
    }

    @Test func hexRoundTrip() {
        let rgb = RGB(hexString: "#FF9F0A")!
        #expect(rgb == RGB(hex: 0xFF9F0A))
        #expect(rgb.hexString == "#FF9F0A")
        #expect(RGB(hexString: "33aa77")?.hexString == "#33AA77")
        #expect(RGB(hexString: "#12") == nil)
        #expect(RGB(hexString: "nothex") == nil)
    }

    @Test func locationUpdatesOnlyAfterMovingTenKilometers() {
        let downtown = SavedPlace(name: "Houston", latitude: 29.7604, longitude: -95.3698)
        // ~2 km away: same place.
        #expect(!LocationService.movedEnough(from: downtown, to: CLLocationCoordinate2D(latitude: 29.7420, longitude: -95.3700)))
        // Katy, ~45 km: new place.
        #expect(LocationService.movedEnough(from: downtown, to: CLLocationCoordinate2D(latitude: 29.7858, longitude: -95.8245)))
    }
}
