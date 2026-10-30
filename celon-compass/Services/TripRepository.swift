//
//  TripRepository.swift
//  celon-compass
//

import CoreData
import WidgetKit

@MainActor
struct TripRepository {
    let context: NSManagedObjectContext
    private let guardian: DestructiveActionGuard
    private let routing: RoutingServicing

    init(context: NSManagedObjectContext, guardian: DestructiveActionGuard? = nil, routing: RoutingServicing = HaversineRoutingService()) {
        self.context = context
        self.guardian = guardian ?? DestructiveActionGuard()
        self.routing = routing
    }


    private func didMutate() {
        SyncCoordinator.shared.enqueue()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    func createTrip(title: String) throws -> Itinerary {
        let trip = Itinerary(context: context)
        trip.id = UUID()
        trip.title = title
        trip.createdAt = Date()
        trip.status = "planned"
        trip.touch()
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
        return trip
    }


    func deleteTrip(_ trip: Itinerary) async throws {
        try await guardian.perform(reason: "Confirm deleting this trip") {
            guard !trip.isDeleted else { return }
            // Record a tombstone for sync propagation if the trip has a remoteID
            if let remoteID = trip.remoteID {
                let tombstone = Tombstone(context: context)
                tombstone.id = UUID()
                tombstone.path = "trips/\(remoteID)"
                tombstone.createdAt = Date()
                // Also tombstone its stops
                for stop in (trip.stops as? Set<ItineraryStop>) ?? [] {
                    if let stopRemoteID = stop.remoteID {
                        let st = Tombstone(context: context)
                        st.id = UUID()
                        st.path = "trips/\(remoteID)/stops/\(stopRemoteID)"
                        st.createdAt = Date()
                    }
                }
            }
            context.delete(trip)
            do {
                try context.save()
                didMutate()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    @discardableResult
    func addStop(to trip: Itinerary, poi: POI, date: Date, sortIndex: Int16) throws -> ItineraryStop {
        let stop = ItineraryStop(context: context)
        stop.id = UUID()
        stop.poiName = poi.name
        stop.poiCategory = poi.category
        stop.poiLatitude = poi.coordinate.latitude
        stop.poiLongitude = poi.coordinate.longitude
        stop.poiSource = poi.source.rawValue
        stop.date = date
        stop.sortOrder = sortIndex
        stop.destination = poi.destination
        stop.itinerary = trip
        stop.touch()
        trip.touch()
        applyConflictFlags(for: trip)
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
        return stop
    }

    func reorder(_ stops: [ItineraryStop]) throws {
        for (index, stop) in stops.enumerated() {
            stop.sortOrder = Int16(index)
            stop.touch()
        }
        if let trip = stops.first?.itinerary {
            applyConflictFlags(for: trip)
        }
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
    }

    func moveStop(_ stop: ItineraryStop, to newDate: Date) throws {
        stop.date = newDate
        stop.touch()
        if let trip = stop.itinerary {
            syncDateRange(for: trip)
            trip.touch()
            applyConflictFlags(for: trip)
        }
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
    }

     private func syncDateRange(for trip: Itinerary) {
        let dates = ((trip.stops as? Set<ItineraryStop>) ?? []).compactMap(\.date)
        guard !dates.isEmpty else { return }
        trip.startDate = dates.min()
        trip.endDate = dates.max()
    }

    func renameTrip(_ trip: Itinerary, to title: String) throws {
        trip.title = title
        trip.touch()
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteStop(_ stop: ItineraryStop) throws {
        // Tombstone for sync propagation
        if let remoteID = stop.remoteID, let tripRemoteID = stop.itinerary?.remoteID {
            let tombstone = Tombstone(context: context)
            tombstone.id = UUID()
            tombstone.path = "trips/\(tripRemoteID)/stops/\(remoteID)"
            tombstone.createdAt = Date()
        }
        let trip = stop.itinerary
        context.delete(stop)
        trip?.touch()
        if let trip { applyConflictFlags(for: trip) }
        do {
            try context.save()
            didMutate()
        } catch {
            context.rollback()
            throw error
        }
    }

   
    // Priority when a stop is flagged by more than one rule: storm risk, travel-time,same day double booking
    func recomputeConflicts(for trip: Itinerary) throws {
        applyConflictFlags(for: trip)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

        private func applyConflictFlags(for trip: Itinerary) {
        let stops = Array((trip.stops as? Set<ItineraryStop>) ?? []).filter { !$0.isDeleted }
        let forecasts = cachedForecasts(for: stops)

        let stormIDs = ConflictRules.flagStormRisk(stops, forecasts: forecasts)
        let travelTimeIDs = ConflictRules.flagTravelTime(stops, routing: routing)
        let doubleBookedIDs = ConflictRules.sameDayStopIDs(stops)

        for stop in stops {
            guard let id = stop.id else { continue }
            if stormIDs.contains(id) {
                stop.hasConflict = true
                stop.conflictKind = "stormRisk"
            } else if travelTimeIDs.contains(id) {
                stop.hasConflict = true
                stop.conflictKind = "travelTime"
            } else if doubleBookedIDs.contains(id) {
                stop.hasConflict = true
                stop.conflictKind = "doubleBooked"
            } else {
                stop.hasConflict = false
                stop.conflictKind = nil
            }
        }
    }

      private func cachedForecasts(for stops: [ItineraryStop]) -> [UUID: [DayForecast]] {
        let destinationIDs = Set(stops.compactMap { $0.destination?.id })
        var result: [UUID: [DayForecast]] = [:]
        for id in destinationIDs {
            if let forecasts = WeatherCache.freshForecasts(for: id, ttl: 3 * 3600, context: context) {
                result[id] = forecasts
            }
        }
        return result
    }
}
