//
//  HeroDestinationView.swift
//  celon-compass

import SwiftUI

struct HeroDestinationView: View {
    @ObservedObject var destination: Destination
    let forecast: DayForecast?
    var favouritesStore: FavouritesStore = .shared

    private var id: UUID { destination.id ?? UUID() }
    private var isFavourite: Bool { favouritesStore.isFavourite(id) }

    var body: some View {
        Color.clear
            .frame(height: 240)
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
                    colors: [.clear, .clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                Text("Best weather today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppBrand.tealTop.opacity(0.85), in: Capsule())
                    .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    favouritesStore.toggle(id)
                } label: {
                    Image(systemName: isFavourite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavourite ? AppBrand.amber : .white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(destination.name ?? "Unknown")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        if let province = destination.province {
                            Label(province, systemImage: "mappin")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        if let forecast {
                            HStack(spacing: 4) {
                                Image(systemName: forecast.condition.symbolName)
                                Text("\(Int(forecast.high.rounded()))°")
                                Text("·")
                                Image(systemName: "drop.fill")
                                    .font(.caption2)
                                Text("\(forecast.rainProbability)%")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
    }
}
