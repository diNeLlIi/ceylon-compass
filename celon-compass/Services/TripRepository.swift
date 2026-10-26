//
//  TripRepository.swift
//  celon-compass
//

import CoreData

@MainActor
struct TripRepository {
    let context: NSManagedObjectContext
    private let guardian: DestructiveActionGuard

    init(context: NSManagedObjectContext, guardian: DestructiveActionGuard? = nil) {
        self.context = context
        self.guardian = guardian ?? DestructiveActionGuard()
    }

    @discardableResult
    func createTrip(title: String) throws -> Itinerary {
        let trip = Itinerary(context: context)
        trip.id = UUID()
        trip.title = title
        trip.createdAt = Date()
        trip.status = "planned"
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return trip
    }


    func deleteTrip(_ trip: Itinerary) async throws {
        try await guardian.perform(reason: "Confirm deleting this trip") {
            guard !trip.isDeleted else { return }
            context.delete(trip)
            do {
                try context.save()
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
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return stop
    }

       func reorder(_ stops: [ItineraryStop]) throws {
        for (index, stop) in stops.enumerated() {
            stop.sortOrder = Int16(index)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func moveStop(_ stop: ItineraryStop, to newDate: Date) throws {
        stop.date = newDate
        if let trip = stop.itinerary {
            syncDateRange(for: trip)
        }
        do {
            try context.save()
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

    func deleteStop(_ stop: ItineraryStop) throws {
        context.delete(stop)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

   
    func recomputeConflicts(for trip: Itinerary) throws {
        let stops = (trip.stops as? Set<ItineraryStop>) ?? []
        let flaggedIDs = ConflictRules.sameDayStopIDs(Array(stops))
        for stop in stops {
            guard let id = stop.id else { continue }
            let isFlagged = flaggedIDs.contains(id)
            stop.hasConflict = isFlagged
            stop.conflictKind = isFlagged ? "doubleBooked" : nil
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
