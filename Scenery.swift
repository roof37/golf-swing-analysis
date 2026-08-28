//
//  Scenery.swift
//  golf swing analysis
//
//  Shared outdoor scenery for the flight and figure views, tuned to a
//  golf-sim look: deep turf greens, hazy horizons, and muted tree lines.
//  Everything is derived from deterministic hash noise so the scenery holds
//  perfectly still while the physics sliders redraw the shot on top of it.
//

import SwiftUI

enum Scenery {
    /// Deterministic hash noise in 0...1, stable across frames and launches.
    static func noise(_ i: Int, seed: Int = 0) -> Double {
        let v = sin(Double(i * 127 + seed * 311) * 12.9898) * 43758.5453
        return v - v.rounded(.down)
    }

    // Turf palette. Fixed sim-style colors, identical in light and dark mode.
    static let turfDeep = Color(red: 0.025, green: 0.18, blue: 0.07)
    static let turfMid = Color(red: 0.07, green: 0.32, blue: 0.12)
    static let fairway = Color(red: 0.18, green: 0.56, blue: 0.18)
    static let fairwayLight = Color(red: 0.33, green: 0.70, blue: 0.26)
    static let greenSurface = Color(red: 0.38, green: 0.78, blue: 0.30)
    static let treeLine = Color(red: 0.04, green: 0.18, blue: 0.08)
    static let sand = Color(red: 0.82, green: 0.74, blue: 0.55)
    static let sandRim = Color(red: 0.62, green: 0.54, blue: 0.38)
    static let skyTop = Color(red: 0.62, green: 0.78, blue: 0.92)
    static let skyHorizon = Color(red: 0.88, green: 0.93, blue: 0.97)
}

/// Wraps a pre-computed Path so it can be used with `clipShape`.
struct FixedPathShape: Shape {
    let fixed: Path
    func path(in rect: CGRect) -> Path { fixed }
}

// MARK: - Horizon pieces

/// A distant tree-line silhouette with irregular canopy texture instead of
/// rounded scenic hills.
struct TreeLineShape: Shape {
    var seed = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard rect.height > 1, rect.width > 1 else { return p }

        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        var x = rect.minX
        var i = 0
        while x <= rect.maxX {
            let step = max(4, rect.height * (0.18 + 0.22 * Scenery.noise(i, seed: seed)))
            let canopy = rect.height * (0.42 + 0.50 * Scenery.noise(i + 17, seed: seed))
            let understory = rect.height * (0.12 * Scenery.noise(i + 31, seed: seed))
            let y = rect.maxY - canopy + understory
            p.addLine(to: CGPoint(x: min(x, rect.maxX), y: y))
            x += step
            i += 1
        }

        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A soft atmospheric band that sits on the horizon and fades upward — the
/// haze that makes a sim range read as distant instead of drawn.
struct HorizonHaze: View {
    let width: CGFloat
    let horizon: CGFloat
    var height: CGFloat = 44

    var body: some View {
        LinearGradient(
            colors: [Scenery.skyHorizon.opacity(0), Scenery.skyHorizon.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
        .position(x: width / 2, y: horizon - height / 2)
        .allowsHitTesting(false)
    }
}

// MARK: - Top-down pieces

/// Scattered tree clumps lining both margins of a top-down hole: overlapping
/// dark canopies, like a course flyover rather than map icons.
struct TopDownTrees: View {
    let size: CGSize

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                let left = i < 9
                let t = Double(i % 9) / 9
                let fy = 0.04 + 0.72 * t + 0.05 * Scenery.noise(i)
                let edge = 0.040 + 0.055 * Scenery.noise(i + 40)
                let radius = 7.0 + 7.0 * Scenery.noise(i + 80)
                treeClump(radius: radius)
                    .position(
                        x: size.width * (left ? edge : 1 - edge),
                        y: size.height * fy
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func treeClump(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Scenery.treeLine.opacity(0.50))
            Circle()
                .fill(Scenery.treeLine.opacity(0.42))
                .frame(width: radius * 1.3, height: radius * 1.3)
                .offset(x: radius * 0.5, y: radius * 0.3)
            Circle()
                .fill(Scenery.treeLine.opacity(0.46))
                .frame(width: radius * 1.1, height: radius * 1.1)
                .offset(x: -radius * 0.45, y: radius * 0.15)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

/// A sand bunker for the top-down view; rotate at the use site for variety.
struct BunkerBlob: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Scenery.sand.opacity(0.9))
            Ellipse().stroke(Scenery.sandRim.opacity(0.6), lineWidth: 1)
        }
    }
}

// MARK: - Ground texture

/// Sparse grass blades for close-up ground views.
struct GrassTexture: View {
    var bladeCount = 60
    var tint = Color.white.opacity(0.10)

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<bladeCount {
                let x = Scenery.noise(i, seed: 3) * size.width
                let y = Scenery.noise(i, seed: 7) * size.height
                let lean = (Scenery.noise(i, seed: 11) - 0.5) * 3
                var blade = Path()
                blade.move(to: CGPoint(x: x, y: y))
                blade.addLine(to: CGPoint(x: x + lean, y: y - 4))
                ctx.stroke(blade, with: .color(tint), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
