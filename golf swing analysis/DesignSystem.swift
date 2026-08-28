//
//  DesignSystem.swift
//  golf swing analysis
//
//  A small shared design system so every tab has the same visual rhythm:
//  one card surface, one section header, a fixed spacing scale, a consistent
//  screen scaffold, and a single set of semantic colors.
//

import SwiftUI

enum Theme {
    // Spacing
    static let gap: CGFloat = 16          // between cards / major blocks
    static let innerGap: CGFloat = 10     // within a card
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let insetRadius: CGFloat = 10

    // Surfaces
    static let card = Color(.secondarySystemBackground)
    static let inset = Color(.tertiarySystemFill)
    static let field = Color(.systemGreen).opacity(0.12)   // the "grass" panel

    // Semantic colors (used consistently app-wide)
    static let path = Color.blue.opacity(0.86)      // club path / swing direction
    static let face = Color.orange.opacity(0.88)    // club face / ball / flight
    static let target = Color.secondary             // target line
    static let good = Color.green.opacity(0.82)
    static let warn = Color.orange.opacity(0.82)
    static let bad = Color.red.opacity(0.86)
}

extension View {
    /// Standard card surface.
    func card(_ padding: CGFloat = Theme.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    /// Standard "grass" hero panel for a main visualization.
    func fieldPanel(height: CGFloat) -> some View {
        self
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// A consistent section header (icon optional).
struct SectionHeader: View {
    let title: String
    var systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A titled card: header + content, on the standard card surface.
struct CardSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.innerGap) {
            SectionHeader(title, systemImage: systemImage)
            content
        }
        .card()
    }
}

/// Consistent screen scaffold: navigation title + scrolling content with
/// standard padding and inter-card spacing.
struct Screen<Content: View>: View {
    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode
    @ViewBuilder var content: Content

    init(_ title: String,
         titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.gap) {
                    content
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(titleDisplayMode)
        }
    }
}
