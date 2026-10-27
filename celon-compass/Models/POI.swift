//
//  POI.swift
//  celon-compass
//
//

import Foundation

struct POI: Identifiable, Equatable {
    enum Source: String {
        case catalog
        case osm
    }

    let id: String
    let name: String
    let category: String?
    let coordinate: Coordinate
    let source: Source
   
    let destination: Destination?

    init(destination: Destination) {
        self.id = destination.id?.uuidString ?? UUID().uuidString
        self.name = destination.name ?? "Unknown"
        self.category = destination.category
        self.coordinate = Coordinate(latitude: destination.latitude, longitude: destination.longitude)
        self.source = .catalog
        self.destination = destination
    }

    
    init(gem: OSMGem) {
        self.id = "osm:\(gem.osmId)"
        self.name = gem.name
        self.category = gem.category
        self.coordinate = gem.coordinate
        self.source = .osm
        self.destination = nil
    }
}
