//
//  WeatherError.swift
//  celon-compass
//

import Foundation

enum WeatherError: Error {
    case network(Error)
    case decoding(Error)
    case noConnection

    static func map(_ error: Error) -> WeatherError {
        if let urlError = error as? URLError,
           urlError.code == .notConnectedToInternet || urlError.code == .timedOut {
            return .noConnection
        }
        if error is DecodingError {
            return .decoding(error)
        }
        return .network(error)
    }
}
