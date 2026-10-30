//
//  AddToTripIntent.swift
//  celon-compass
//

import AppIntents
import CoreData
import Foundation

struct AddToTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Trip"
    static var description = IntentDescription("Adds a destination to one of your trips.")

    @Parameter(title: "Destination")
    var destination: DestinationEntity

    @Parameter(title: "Trip")
    var trip: TripEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$destination) to \(\.$trip)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        guard let destinationUUID = UUID(uuidString: destination.id),
              let tripUUID = UUID(uuidString: trip.id)
        else {
            return .result(dialog: "I couldn't find that destination or trip.")
        }

        let destinationRequest = Destination.fetchRequest()
        destinationRequest.predicate = NSPredicate(format: "id == %@", destinationUUID as CVarArg)
        destinationRequest.fetchLimit = 1

        let tripRequest = Itinerary.fetchRequest()
        tripRequest.predicate = NSPredicate(format: "id == %@", tripUUID as CVarArg)
        tripRequest.fetchLimit = 1

        guard let destinationObject = try context.fetch(destinationRequest).first,
              let tripObject = try context.fetch(tripRequest).first
        else {
            return .result(dialog: "I couldn't find that destination or trip.")
        }

        let repository = TripRepository(context: context)
        let stopCount = (tripObject.stops as? Set<ItineraryStop>)?.count ?? 0
        let date = tripObject.endDate.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!

        try repository.addStop(to: tripObject, poi: POI(destination: destinationObject), date: date, sortIndex: Int16(stopCount))
        tripObject.startDate = [tripObject.startDate, date].compactMap { $0 }.min()
        tripObject.endDate = [tripObject.endDate, date].compactMap { $0 }.max()
        try context.save()

        return .result(dialog: "Added \(destination.name) to \(trip.title).")
    }
}
