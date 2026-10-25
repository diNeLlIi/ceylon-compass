//
//  DestinationCardView.swift
//  celon-compass

import SwiftUI
import CoreData

struct DestinationCardView: View {
    enum CompareMode {
        case off
        case selectable(isSelected: Bool, onToggle: () -> Void)
        case disabled
    }

    @ObservedObject var destination: Destination
    let forecast: DayForecast?
    var favouritesStore: FavouritesStore = .shared
    var compareMode: CompareMode = .off

    private var id: UUID { destination.id ?? UUID() }
    private var isFavourite: Bool { favouritesStore.isFavourite(id) }

    var body: some View {
        Color.clear
            .frame(height: 200)
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
                WeatherBadgeView(forecast: forecast)
                    .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                topTrailingControl
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(nameText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let category = destination.category {
                            Text(category.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        if destination.category != nil && destination.province != nil {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        if let province = destination.province {
                            Text(province)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .opacity(isDisabledForCompare ? 0.6 : 1)
            .allowsHitTesting(!isDisabledForCompare)
    }

    private var isDisabledForCompare: Bool {
        if case .disabled = compareMode { return true }
        return false
    }

    private var nameText: String {
        let name = destination.name ?? "Unknown"
        guard isFavourite, case .selectable = compareMode else { return name }
        return "\(name) · favourite"
    }

    @ViewBuilder
    private var topTrailingControl: some View {
        switch compareMode {
        case .off:
            favoriteButton
        case .selectable(let isSelected, let onToggle):
            selectionCircle(isSelected: isSelected, onToggle: onToggle)
        case .disabled:
            staticHeart
        }
    }

    private var favoriteButton: some View {
        Button {
            favouritesStore.toggle(id)
        } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavourite ? AppBrand.amber : .white)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(10)
    }

    private var staticHeart: some View {
        Image(systemName: isFavourite ? "heart.fill" : "heart")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isFavourite ? AppBrand.amber : .white)
            .padding(8)
            .background(.ultraThinMaterial, in: Circle())
            .padding(10)
    }

    private func selectionCircle(isSelected: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? AppBrand.tealTop : .white)
                .background(isSelected ? Color.clear : .black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(10)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let destination = Destination(context: context)
    destination.id = UUID()
    destination.name = "Sigiriya"
    destination.category = "Heritage"
    destination.province = "Central"
    destination.imageURL = "https://upload.wikimedia.org/wikipedia/commons/c/c7/Sigiriya.jpg"
    let favouritesStore = FavouritesStore(context: context)

    return HStack(alignment: .top, spacing: 16) {
        DestinationCardView(
            destination: destination,
            forecast: DayForecast(date: .now, high: 31, low: 24, rainProbability: 10, uvIndex: 8, condition: .clear),
            favouritesStore: favouritesStore
        )
        DestinationCardView(destination: destination, forecast: nil, favouritesStore: favouritesStore)
    }
    .padding()
}
