//
//  LocationService.swift
//  celon-compass
//
//  Geofences the active trip's stops and posts an arrival notification.


import CoreData
import CoreLocation
import Observation
import UserNotifications
import WidgetKit

struct ResolvedOrigin: Equatable {
    let coordinate: Coordinate
    let name: String
}

protocol OriginLocating {
    func resolveOrigin() async -> ResolvedOrigin?
}

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate, OriginLocating {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let context: NSManagedObjectContext

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    @ObservationIgnored private var oneShotWaiters: [CheckedContinuation<CLLocation?, Never>] = []


    func currentLocationOnce(timeoutSeconds: Double = 8) async -> CLLocation? {
        // locationServicesEnabled() is a blocking call: if services are off,
        // authorization is denied/restricted or requestLocation() fails via didFailWithError
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        default:
            break
        }

        if let cached = manager.location, cached.timestamp.timeIntervalSinceNow > -60 {
            currentLocation = cached
            return cached
        }

        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self else { return nil }
                return await withCheckedContinuation { continuation in
                    self.oneShotWaiters.append(continuation)
                    self.manager.requestLocation()
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    func resolveOrigin() async -> ResolvedOrigin? {
        guard let location = await currentLocationOnce() else { return nil }
        let coordinate = Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        return ResolvedOrigin(coordinate: coordinate, name: await Self.placeName(for: location))
    }

    
    private static func placeName(for location: CLLocation) async -> String {
        let generic = "Current location"
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return generic
        }
        guard let locality = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea else {
            return generic
        }
        return "\(generic) · \(locality)"
    }

    private func resumeOneShotWaiters(with location: CLLocation?) {
        let waiters = oneShotWaiters
        oneShotWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: location)
        }
    }


    func monitorStops(_ stops: [ItineraryStop]) {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        for stop in stops.prefix(20) {
            guard let id = stop.id else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: stop.poiLatitude, longitude: stop.poiLongitude),
                radius: 200,
                identifier: id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    // Stops monitoring geofences for stops of a completed trip
    func stopMonitoring(_ stops: [ItineraryStop]) {
        let stopIDs = Set(stops.compactMap { $0.id?.uuidString })
        for region in manager.monitoredRegions where stopIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .denied, .restricted:
            resumeOneShotWaiters(with: nil)
        case .authorizedWhenInUse, .authorizedAlways:
            
            if !oneShotWaiters.isEmpty { manager.requestLocation() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        resumeOneShotWaiters(with: locations.last)
    }

    //  a failed fix leaves currentLocationOnce() hanging until its timeout without this
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resumeOneShotWaiters(with: nil)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed for \(region?.identifier ?? "unknown region"): \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        postArrivalNotification(stopID: region.identifier)
    }

    private func postArrivalNotification(stopID: String) {
        guard let uuid = UUID(uuidString: stopID) else { return }
        let request = ItineraryStop.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        guard let stop = try? context.fetch(request).first else { return }

        
        if let destination = stop.destination {
            Task { @MainActor in
                VisitLogger(context: context).recordArrival(at: destination)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()

        let content = UNMutableNotificationContent()
        content.title = "Arriving at \(stop.poiName ?? "your next stop")"
        content.body = arrivalBody(for: stop)
        content.sound = .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private func arrivalBody(for stop: ItineraryStop) -> String {
        guard let destinationID = stop.destination?.id,
              let date = stop.date,
              let forecast = WeatherCache.freshForecasts(for: destinationID, ttl: 3 * 3600, context: context)?
                .first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        else {
            return "You've arrived at \(stop.poiName ?? "this stop")."
        }
        return "\(Int(forecast.high.rounded()))°, \(forecast.condition.label.lowercased()) today."
    }
}
