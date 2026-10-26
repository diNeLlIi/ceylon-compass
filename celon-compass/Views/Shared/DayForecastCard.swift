//
//  DayForecastCard.swift
//  celon-compass
//
//  One day in Destination Detail's 7-day forecast strip
//

import SwiftUI

struct DayForecastCard: View {
    let forecast: DayForecast
    var isToday: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(isToday ? "Today" : weekdayText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(systemName: forecast.condition.symbolName)
                .font(.title3)
                .foregroundStyle(AppBrand.tealTop)
                .symbolRenderingMode(.hierarchical)

            HStack(spacing: 3) {
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.caption.weight(.semibold))
                Text("\(Int(forecast.low.rounded()))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if forecast.rainProbability > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                    Text("\(forecast.rainProbability)%")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64)
        .padding(.vertical, 10)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var weekdayText: String {
        forecast.date.formatted(.dateTime.weekday(.abbreviated))
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { offset in
                DayForecastCard(
                    forecast: DayForecast(
                        date: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
                        high: 24 + Double(offset),
                        low: 16 + Double(offset),
                        rainProbability: [20, 10, 45, 80, 35, 10, 15][offset],
                        uvIndex: 7,
                        condition: [.cloudy, .clear, .cloudy, .storm, .cloudy, .clear, .clear][offset]
                    ),
                    isToday: offset == 0
                )
            }
        }
        .padding()
    }
    .background(AppBrand.canvas)
}
