import CoreLocation

/// Gets the Mac's location once ("When In Use"), names it with reverse geocoding, and
/// reports a new place only when it has moved more than about 10 km.
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case unknown, denied, authorized
    }

    static let minimumMove: CLLocationDistance = 10_000

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastPlace: SavedPlace?
    private var isActive = false

    private(set) var status: Status = .unknown {
        didSet { if status != oldValue { onStatus?(status) } }
    }
    var onPlace: ((SavedPlace) -> Void)?
    var onStatus: ((Status) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Starts (or restarts) using Location Services, asking permission the first time.
    func start(lastKnown: SavedPlace?) {
        lastPlace = lastKnown
        isActive = true
        evaluate(manager.authorizationStatus)
    }

    func stop() {
        isActive = false
    }

    /// Re-checks the location, e.g. after waking from sleep.
    func refresh() {
        guard isActive, status == .authorized else { return }
        manager.requestLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        evaluate(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive, let location = locations.last else { return }
        if let lastPlace, !Self.movedEnough(from: lastPlace, to: location.coordinate) { return }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let mark = placemarks?.first
            let place = SavedPlace(
                name: mark?.locality ?? mark?.administrativeArea ?? mark?.name ?? "Current location",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            self?.lastPlace = place
            Log.location.notice("Location: \(place.name, privacy: .public)")
            self?.onPlace?(place)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Location failed: \(error.localizedDescription, privacy: .public)")
    }

    private func evaluate(_ authorization: CLAuthorizationStatus) {
        guard isActive else { return }
        switch authorization {
        case .notDetermined:
            status = .unknown
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
            Log.location.notice("Location access denied")
        default:
            status = .authorized
            manager.requestLocation()
        }
    }

    // MARK: Helpers

    static func movedEnough(from place: SavedPlace, to coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: place.latitude, longitude: place.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) > minimumMove
    }

    /// Looks up a typed city ("Houston", "London, UK").
    static func geocode(_ query: String, completion: @escaping (Result<SavedPlace, Error>) -> Void) {
        CLGeocoder().geocodeAddressString(query) { placemarks, error in
            if let mark = placemarks?.first, let location = mark.location {
                completion(.success(SavedPlace(
                    name: mark.locality ?? mark.name ?? query,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )))
            } else {
                completion(.failure(error ?? CLError(.geocodeFoundNoResult)))
            }
        }
    }
}
