//
//  VisitLogger.swift
//  celon-compass
//
//  Writes VisitRecord

import CoreData
import Foundation

@MainActor
struct VisitLogger {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    @discardableResult
    func markVisited(
        _ destination: Destination,
        on date: Date = .now,
        rating: Int16 = 0,
        note: String? = nil
    ) throws -> VisitRecord? {
        guard !hasRecord(for: destination, on: date) else { return nil }
        let record = make(destination: destination, date: date, rating: rating, note: note)
        try save()
        return record
    }

    func update(_ record: VisitRecord, rating: Int16, note: String?) throws {
        record.rating = rating
        record.note = note
        try save()
    }

    func delete(_ record: VisitRecord) throws {
        context.delete(record)
        try save()
    }

    // Derives a visit for every stop already in the past so the map shows ghost pins
    func backfillFromPastTrips(now: Date = .now) throws {
        let request = ItineraryStop.fetchRequest()
        request.predicate = NSPredicate(
            format: "date < %@ AND destination != nil",
            Calendar.current.startOfDay(for: now) as NSDate
        )

        var didWrite = false
        for stop in try context.fetch(request) {
            guard let destination = stop.destination, let date = stop.date else { continue }
            guard !hasRecord(for: destination, on: date) else { continue }
            make(destination: destination, date: date, rating: 0, note: nil)
            didWrite = true
        }
        if didWrite { try save() }
    }

    
    func recordArrival(at destination: Destination, on date: Date = .now) {
        try? markVisited(destination, on: date)
    }

    func hasRecord(for destination: Destination, on date: Date) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }

        let request = VisitRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "destination == %@ AND visitDate >= %@ AND visitDate < %@",
            destination, start as NSDate, end as NSDate
        )
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    @discardableResult
    private func make(destination: Destination, date: Date, rating: Int16, note: String?) -> VisitRecord {
        let record = VisitRecord(context: context)
        record.id = UUID()
        record.destination = destination
        record.visitDate = date
        record.rating = rating
        record.note = note
        return record
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
