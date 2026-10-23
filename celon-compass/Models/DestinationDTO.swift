//
//  DestinationDTO.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

struct DestinationDTO: Codable, Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let category: String
    let province: String
    let district: String
    let descriptionText: String
    let imageURL: String
}
