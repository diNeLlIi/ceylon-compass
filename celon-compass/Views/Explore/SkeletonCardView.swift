//
//  SkeletonCardView.swift
//  celon-compass

import SwiftUI

struct SkeletonCardView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
                .frame(height: 180)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.15), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmer ? 200 : -200)
                }
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 100, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 60, height: 10)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}

struct SkeletonGridView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Hero skeleton
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.tertiarySystemBackground))
                .frame(height: 240)
                .padding(.horizontal)

            // Grid skeletons
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCardView()
                }
            }
            .padding(.horizontal)
        }
    }
}
