//
//  LocationService.swift
//  celon-compass
//
//  Geofences the active trip's stops and posts an arrival notification.


import CoreData
import CoreLocation
import Observation
import UserNotifications

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
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
