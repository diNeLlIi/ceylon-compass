//
//  JSONLoader.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

internal import Foundation

func loadFromBundle<T: Decodable>(_ filename: String) throws -> T {
    guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
        throw URLError(.fileDoesNotExist)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}
