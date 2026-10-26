//
//  ForecastChartsView.swift
//  celon-compass
//
//  Two single axis charts under Destination Detail's forecast strip
//

import SwiftUI
import Charts

struct ForecastChartsView: View {
    let forecasts: [DayForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            chartBlock(title: "Daily high temperature", unit: "°C") {
                Chart(forecasts) { forecast in
                    LineMark(
                        x: .value("Day", forecast.date, unit: .day),
                        y: .value("High", forecast.high)
                    )
                    .foregroundStyle(AppBrand.tealTop)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Day", forecast.date, unit: .day),
                        y: .value("High", forecast.high)
                    )
                    .foregroundStyle(AppBrand.tealTop)
                    .symbolSize(28)
                    .annotation(position: .top) {
                        Text("\(Int(forecast.high.rounded()))°")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            chartBlock(title: "Chance of rain", unit: "%") {
                Chart(forecasts) { forecast in
                    BarMark(
                        x: .value("Day", forecast.date, unit: .day),
                        y: .value("Rain", forecast.rainProbability)
                    )
                    .foregroundStyle(forecast.rainProbability >= 50 ? AppBrand.destructive : AppBrand.tealTop)
                    .cornerRadius(3)
                    .annotation(position: .top) {
                        Text("\(forecast.rainProbability)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(forecast.rainProbability >= 50 ? AppBrand.destructive : .secondary)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func chartBlock<Content: View>(title: String, unit: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            content()
                .frame(height: 140)
        }
        .padding(14)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    let forecasts = (0..<7).map { offset in
        DayForecast(
            date: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
            high: [24, 25, 23, 22, 24, 26, 25][offset],
            low: [16, 17, 16, 16, 17, 18, 17][offset],
            rainProbability: [20, 10, 45, 80, 35, 10, 15][offset],
            uvIndex: 6,
            condition: [.cloudy, .clear, .cloudy, .storm, .cloudy, .clear, .clear][offset]
        )
    }
    return ScrollView {
        ForecastChartsView(forecasts: forecasts)
            .padding(.vertical)
    }
    .background(AppBrand.canvas)
}
