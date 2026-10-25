//
//  DestinationFeatureCardView.swift
//  celon-compass

import SwiftUI

struct DestinationFeatureCardView: View {
    @ObservedObject var destination: Destination
    let forecast: DayForecast?
    var favouritesStore: FavouritesStore = .shared

    private var id: UUID { destination.id ?? UUID() }
    private var isFavourite: Bool { favouritesStore.isFavourite(id) }

    var body: some View {
        Color.clear
            .frame(width: 180, height: 220)
            .overlay {
                AsyncImage(url: destination.imageURL.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color(.tertiarySystemBackground))
                    }
                }
            }
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    favouritesStore.toggle(id)
                } label: {
                    Image(systemName: isFavourite ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFavourite ? AppBrand.amber : .white)
                        .padding(7)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name ?? "Unknown")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let province = destination.province {
                        Text(province)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if let forecast {
                        HStack(spacing: 4) {
                            Image(systemName: forecast.condition.symbolName)
                                .font(.caption2)
                            Text("\(Int(forecast.high.rounded()))°/\(Int(forecast.low.rounded()))°")
                                .font(.caption2.weight(.semibold))

                            Spacer()

                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                Text("\(forecast.rainProbability)%")
                                    .font(.caption2.weight(.medium))
                            }
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
