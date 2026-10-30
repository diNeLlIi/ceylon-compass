//
//  SwipeActionsCard.swift
//  celon-compass
//
//  Reveals Edit/Delete on a left swipe for cards living outside a List, where
//  the native .swipeActions modifier doesn't apply (trip and memory grids/stacks).

import CoreData
import SwiftUI

struct SwipeActionsCard<Content: View>: View {
    let id: NSManagedObjectID
    @Binding var openID: NSManagedObjectID?
    var cornerRadius: CGFloat = 16
    var onEdit: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0
    private let actionWidth: CGFloat = 148
    private let openAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    private var isOpen: Bool { openID == id }
    private var resolvedOffset: CGFloat {
        max(-actionWidth, min(0, (isOpen ? -actionWidth : 0) + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionsRow

            content()
                .contentShape(Rectangle())
                .offset(x: resolvedOffset)
                .overlay {
                    // Swallows taps while open so they close the swipe instead of
                    // reaching the NavigationLink/Button underneath.
                    if isOpen {
                        Color.black.opacity(0.001)
                            .onTapGesture { close() }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let projected = (isOpen ? -actionWidth : 0) + value.translation.width
                            withAnimation(openAnimation) {
                                dragOffset = 0
                                openID = projected < -actionWidth / 2 ? id : nil
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func close() {
        withAnimation(openAnimation) { openID = nil }
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            Button {
                close()
                onEdit()
            } label: {
                actionLabel(systemImage: "pencil", title: "Edit")
            }
            .background(AppBrand.link)

            Button(role: .destructive) {
                close()
                onDelete()
            } label: {
                actionLabel(systemImage: "trash", title: "Delete")
            }
            .background(AppBrand.destructive)
        }
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .frame(width: actionWidth / 2)
        .frame(maxHeight: .infinity)
        .foregroundStyle(.white)
    }
}
