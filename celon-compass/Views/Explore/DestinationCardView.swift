//
//  DestinationCardView.swift
//  celon-compass

import SwiftUI
import CoreData

struct DestinationCardView: View {
    @ObservedObject var destination: Destination
    let forecast: DayForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.name ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let category = destination.category {
                    Text(category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppBrand.link)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    private var photo: some View {
        Color.clear
            .frame(height: 140)
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
            .overlay(alignment: .topLeading) {
                WeatherBadgeView(forecast: forecast)
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                favoriteButton
            }
    }

    private var favoriteButton: some View {
        Button {
            destination.isFavourite.toggle()
            try? destination.managedObjectContext?.save()
        } label: {
            Image(systemName: destination.isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(destination.isFavourite ? AppBrand.amber : .white)
                .padding(8)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let destination = Destination(context: context)
    destination.id = UUID()
    destination.name = "Sigiriya"
    destination.category = "Heritage"
    destination.imageURL = "https://upload.wikimedia.org/wikipedia/commons/c/c7/Sigiriya.jpg"

    return HStack(alignment: .top, spacing: 16) {
        DestinationCardView(
            destination: destination,
            forecast: DayForecast(date: .now, high: 31, low: 24, rainProbability: 10, uvIndex: 8, condition: .clear)
        )
        DestinationCardView(destination: destination, forecast: nil)
    }
    .padding()
}
