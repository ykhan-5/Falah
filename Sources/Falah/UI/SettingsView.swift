import Adhan
import AppKit
import ServiceManagement
import SwiftUI

/// Shows the Settings window. Falah has no Dock icon, so the app is activated briefly to
/// bring the window forward. Closing it hands back to the card via `onClose`.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var onClose: (() -> Void)?
    private let store: SettingsStore
    private let environment: SettingsEnvironment

    init(store: SettingsStore, environment: SettingsEnvironment) {
        self.store = store
        self.environment = environment
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store, environment: environment))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Falah Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

/// Live state and actions the Settings view needs from the app.
@Observable
final class SettingsEnvironment {
    var locationStatus: LocationService.Status = .unknown
    @ObservationIgnored var previewFlash: () -> Void = {}
}

struct SettingsView: View {
    @Bindable var store: SettingsStore
    let environment: SettingsEnvironment

    @State private var cityQuery = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginMessage: String?

    var body: some View {
        Form {
            location
            calculation
            adjustments
            menuBarAndAlerts
            general
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
    }

    // MARK: Location

    private var location: some View {
        Section("Location") {
            Picker("Location", selection: $store.locationMode) {
                Text("Automatic").tag(LocationMode.automatic)
                Text("City or coordinates").tag(LocationMode.manual)
            }
            .pickerStyle(.segmented)

            if store.locationMode == .automatic {
                LabeledContent("Current") {
                    if let place = store.autoPlace {
                        Text("\(place.name) · \(coordinates(place))")
                    } else if environment.locationStatus == .denied {
                        Text("Location access is off").foregroundStyle(.secondary)
                    } else {
                        Text("Finding your location…").foregroundStyle(.secondary)
                    }
                }
                if environment.locationStatus == .denied {
                    Button("Open Location Services Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                    }
                    Text("Until then, Falah uses the city below if you set one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.locationMode == .manual || environment.locationStatus == .denied {
                HStack {
                    TextField("City", text: $cityQuery, prompt: Text("e.g. Houston or London, UK"))
                        .onSubmit(findCity)
                    Button(isSearching ? "Finding…" : "Find", action: findCity)
                        .disabled(cityQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
                if let searchError {
                    Text(searchError).font(.caption).foregroundStyle(.red)
                }
                if let place = store.manualPlace {
                    LabeledContent("Using", value: place.name)
                }
                LabeledContent("Latitude") {
                    TextField("Latitude", value: coordinateBinding(\.latitude), format: .number.precision(.fractionLength(4)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Longitude") {
                    TextField("Longitude", value: coordinateBinding(\.longitude), format: .number.precision(.fractionLength(4)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func findCity() {
        let query = cityQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = nil
        LocationService.geocode(query) { result in
            isSearching = false
            switch result {
            case .success(let place):
                store.manualPlace = place
                cityQuery = ""
            case .failure:
                searchError = "Couldn't find “\(query)”. Try adding the country."
            }
        }
    }

    /// Edits one coordinate of the typed place, creating it if needed.
    private func coordinateBinding(_ keyPath: WritableKeyPath<SavedPlace, Double>) -> Binding<Double> {
        Binding(
            get: { store.manualPlace?[keyPath: keyPath] ?? 0 },
            set: { value in
                var place = store.manualPlace ?? SavedPlace(name: "Custom location", latitude: 0, longitude: 0)
                guard place[keyPath: keyPath] != value else { return }
                place[keyPath: keyPath] = value
                place.name = "Custom location"
                store.manualPlace = place
            }
        )
    }

    private func coordinates(_ place: SavedPlace) -> String {
        String(format: "%.2f, %.2f", place.latitude, place.longitude)
    }

    // MARK: Calculation

    private var calculation: some View {
        Section("Calculation") {
            Picker("Method", selection: $store.method) {
                ForEach(PrayerSettings.selectableMethods, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
            Picker("Asr", selection: $store.madhab) {
                Text("Standard").tag(Madhab.shafi)
                Text("Hanafi").tag(Madhab.hanafi)
            }
            .pickerStyle(.segmented)
            Picker("High-latitude rule", selection: $store.highLatitudeRule) {
                Text("Automatic").tag(HighLatitudeRule?.none)
                ForEach(HighLatitudeRule.allCases, id: \.self) { rule in
                    Text(rule.displayName).tag(HighLatitudeRule?.some(rule))
                }
            }
        }
    }

    // MARK: Masjid adjustments

    private var adjustments: some View {
        Section {
            Toggle("Adjust times for my masjid", isOn: $store.adjustmentsEnabled)
            if store.adjustmentsEnabled {
                ForEach(PrayerName.allCases, id: \.self) { prayer in
                    Stepper(value: adjustmentBinding(prayer), in: -10...10) {
                        LabeledContent(prayer.displayName, value: offsetText(store.adjustments[prayer] ?? 0))
                    }
                }
            }
        } footer: {
            Text("Shift each prayer by up to 10 minutes to match your local masjid's timetable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func adjustmentBinding(_ prayer: PrayerName) -> Binding<Int> {
        Binding(
            get: { store.adjustments[prayer] ?? 0 },
            set: { store.adjustments[prayer] = $0 == 0 ? nil : $0 }
        )
    }

    private func offsetText(_ minutes: Int) -> String {
        minutes == 0 ? "0 min" : String(format: "%+d min", minutes)
    }

    // MARK: Menu bar & alerts

    private var menuBarAndAlerts: some View {
        Section("Menu bar and alerts") {
            Toggle("Show countdown text in menu bar", isOn: $store.showsCountdownText)
            Toggle("Notify at each prayer time", isOn: $store.notificationsEnabled)
            Picker("Reminder before prayer", selection: $store.reminderMinutes) {
                ForEach(SettingsStore.reminderChoices, id: \.self) { minutes in
                    Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                }
            }
            .disabled(!store.notificationsEnabled)
            HStack {
                ColorPicker("Prayer-time flash", selection: momentColor, supportsOpacity: false)
                Button("Preview", action: environment.previewFlash)
            }
        }
    }

    private var momentColor: Binding<Color> {
        Binding(
            get: {
                let rgb = RGB(hexString: store.momentColorHex) ?? RGB(hexString: SettingsStore.defaultMomentColorHex)!
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            },
            set: { color in
                guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                store.momentColorHex = RGB(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent).hexString
            }
        )
    }

    // MARK: General

    private var general: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            if let loginMessage {
                Text(loginMessage).font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
            loginMessage = service.status == .requiresApproval
                ? "Approve Falah in System Settings → General → Login Items."
                : nil
            Log.settings.notice("Launch at login \(enabled ? "on" : "off", privacy: .public), status \(service.status.rawValue)")
        } catch {
            loginMessage = "Couldn't change this: \(error.localizedDescription)"
            Log.settings.error("Launch at login failed: \(error.localizedDescription, privacy: .public)")
            let actual = service.status == .enabled
            if actual != launchAtLogin { launchAtLogin = actual }
        }
    }
}
