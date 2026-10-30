//
//  DayForecastCard.swift
//  celon-compass
//
//  One day in Destination Detail's forecast rail
//

import SwiftUI

struct DayForecastCard: View {
    let forecast: DayForecast
    var isToday: Bool = false
    var isBestWindow: Bool = false

    var body: some View {
        VStack(spacing: 6) {

            Text(isToday ? "Today" : weekdayText)
                .font(.caption2.weight(isToday ? .bold : .semibold))
                .foregroundStyle(isToday ? AppBrand.heading : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(dayNumberText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppBrand.heading)
                Text(monthText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: forecast.condition.symbolName)
                .font(.title3)
                .foregroundStyle(AppBrand.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 26)

            HStack(spacing: 5) {
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppBrand.heading)
                Text("\(Int(forecast.low.rounded()))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            
            
            
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 8))
                Text("\(forecast.rainProbability)%")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .opacity(forecast.rainProbability > 0 ? 1 : 0)
        }
        .frame(width: 78)
        .padding(.vertical, 12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isBestWindow ? AppBrand.accent : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    
    private var cardFill: Color {
        isToday ? AppBrand.cardHighlight : AppBrand.card
    }

    private var weekdayText: String {
        forecast.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var dayNumberText: String {
        forecast.date.formatted(.dateTime.day())
    }

    private var monthText: String {
        forecast.date.formatted(.dateTime.month(.abbreviated))
    }

    private var accessibilityText: String {
        var parts: [String] = [
            isToday ? "Today" : weekdayText,
            "\(dayNumberText) \(monthText)",
            forecast.condition.label,
            "high \(Int(forecast.high.rounded())), low \(Int(forecast.low.rounded()))"
        ]
        if forecast.rainProbability > 0 {
            parts.append("\(forecast.rainProbability) percent chance of rain")
        }
        if isBestWindow {
            parts.append("recommended day")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
            ForEach(0..<10, id: \.self) { offset in
                DayForecastCard(
                    forecast: DayForecast(
                        date: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
                        high: 28 + Double(offset % 4),
                        low: 22 + Double(offset % 2),
                        rainProbability: [100, 71, 84, 65, 27, 0, 75, 73, 88, 90][offset],
                        uvIndex: 7,
                        condition: [.storm, .storm, .rain, .rain, .cloudy, .clear, .rain, .cloudy, .rain, .storm][offset]
                    ),
                    isToday: offset == 0,
                    isBestWindow: offset == 4 || offset == 5
                )
            }
        }
        .padding()
    }
    .background(AppBrand.canvas)
}
