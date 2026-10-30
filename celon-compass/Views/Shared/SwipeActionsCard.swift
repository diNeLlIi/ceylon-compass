//
//  SwipeActionsCard.swift
//  celon-compass
//
//  Reveals its actions on a left swipe for cards living outside a List, where
//  the native .swipeActions modifier doesn't apply (trip and memory grids/stacks).

import CoreData
import SwiftUI

struct SwipeAction {
    let title: String
    let systemImage: String
    let tint: Color
    var role: ButtonRole? = nil
    let perform: () -> Void
}

struct SwipeActionsCard<Content: View>: View {
    let id: NSManagedObjectID
    @Binding var openID: NSManagedObjectID?
    var cornerRadius: CGFloat = 16
    var actions: [SwipeAction]
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0
    private let actionWidth: CGFloat = 74
    private let openAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    private var revealWidth: CGFloat { CGFloat(actions.count) * actionWidth }
    private var isOpen: Bool { openID == id }
    private var resolvedOffset: CGFloat {
        max(-revealWidth, min(0, (isOpen ? -revealWidth : 0) + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionsRow
                .allowsHitTesting(isOpen)

            content()
                .offset(x: resolvedOffset)
                // While open, the content must not take touches so the actions underneath are reachable.
                .allowsHitTesting(!isOpen)

            if isOpen {
                // Covers only the visible card area (left of the actions) and closes the swipe on tap.
                Color.clear
                    .contentShape(Rectangle())
                    .padding(.trailing, revealWidth)
                    .onTapGesture { close() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let projected = (isOpen ? -revealWidth : 0) + value.translation.width
                    withAnimation(openAnimation) {
                        dragOffset = 0
                        openID = projected < -revealWidth / 2 ? id : nil
                    }
                }
        )
    }

    private func close() {
        withAnimation(openAnimation) { openID = nil }
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                Button(role: action.role) {
                    close()
                    action.perform()
                } label: {
                    actionLabel(systemImage: action.systemImage, title: action.title)
                }
                .background(action.tint)
            }
        }
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .frame(width: actionWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .foregroundStyle(.white)
    }
}
