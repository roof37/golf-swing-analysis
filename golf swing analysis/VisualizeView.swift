//
//  VisualizeView.swift
//  golf swing analysis
//
//  The Visualize tab: one shot seen from four angles. A segmented switcher picks
//  the perspective (Front, Top-down, Down-the-line, Club Face); each view draws
//  the ball flight plus the relevant club geometry (path, face, target line) and
//  updates live as the Club Face / Club Path sliders move.
//

import SwiftUI

enum Perspective: String, CaseIterable, Identifiable {
    case front = "Front"
    case top = "Top-down"
    case downLine = "Down-line"
    case face = "Face"

    var id: String { rawValue }

    var blurb: String {
        switch self {
        case .front: return "The shot flying away: watch it rise and curve off into the distance."
        case .top: return "Bird's-eye: the club path (blue) and face aim (orange) set the start and curve."
        case .downLine: return "Behind the player: target, path, and face lines show where it all points."
        case .face: return "Looking down at the ball: tap Swing to watch the face open then close through impact."
        }
    }
}

// MARK: - Shared shot sampling

/// Samples the ball flight in real units: lateral offline (yards, +right) and
/// height (feet) at a given downrange distance.
struct ShotPath {
    let swing: SwingModel

    var carry: Double { max(swing.carryDistance, 1) }
    var maxLateral: Double { max(20, abs(swing.landingOffline) * 1.35) }
    var maxHeight: Double { max(swing.peakHeight, 10) }

    func lateral(at d: Double) -> Double {
        let start = tan(swing.launchDirection * .pi / 180) * d
        let curve = (swing.spinAxis / 45) * carry * 0.5 * pow(d / carry, 2)
        return start + curve
    }

    func height(at d: Double) -> Double {
        let x = min(max(d / carry, 0), 1)
        return swing.peakHeight * sin(.pi * pow(x, 1.15))   // apex just past mid, steeper descent
    }

    /// Fraction of carry where the apex occurs for the height curve above.
    var apexFraction: Double { pow(0.5, 1 / 1.15) }
}

private let dashed = StrokeStyle(lineWidth: 1, dash: [5, 5])

// MARK: - Front view (facing the flight)

struct FrontFlightView: View {
    let swing: SwingModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.28
            let bottomY = h * 0.95
            let cx = w / 2
            let p = ShotPath(swing: swing)
            let lift = (bottomY - horizon) * 0.55

            // Perspective projection: the ball recedes toward the horizon (ease-out),
            // lifting for height and shrinking sideways as it gets farther away.
            let arc: (Double) -> CGPoint = { t in
                let d = p.carry * t
                let recede = 1 - (1 - CGFloat(t)) * (1 - CGFloat(t))
                let baseY = bottomY + (horizon - bottomY) * recede
                let shrink = 1 - 0.8 * CGFloat(t)
                let hy = CGFloat(p.height(at: d) / p.maxHeight) * lift * shrink
                let lateralPx = CGFloat(p.lateral(at: d) / p.maxLateral) * (w * 0.42) * shrink
                return CGPoint(x: cx + lateralPx, y: baseY - hy)
            }
            let ball = CGPoint(x: cx, y: bottomY)

            ZStack {
                // Fairway receding to the horizon.
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.5, y: bottomY))
                    path.addLine(to: CGPoint(x: cx - w * 0.045, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.045, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.5, y: bottomY))
                    path.closeSubpath()
                }
                .fill(.green.opacity(0.18))

                line(CGPoint(x: 0, y: horizon), CGPoint(x: w, y: horizon))
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)

                // Target line to the vanishing point.
                line(ball, CGPoint(x: cx, y: horizon))
                    .stroke(style: dashed).foregroundStyle(.secondary)

                // The shot flying away.
                flightPath(carry: 1, point: arc, steps: 60)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Shrinking ball markers for depth.
                ForEach(1..<7) { i in
                    let t = Double(i) / 6
                    let size = 13 - CGFloat(t) * 9
                    Circle().fill(.orange.opacity(0.9)).frame(width: size, height: size).position(arc(t))
                }

                // Flag marks the target — fixed on the dashed line, not the landing spot.
                flag(at: CGPoint(x: cx, y: horizon))

                // Ball at address.
                Circle().fill(.white).stroke(.orange, lineWidth: 2)
                    .frame(width: 13, height: 13).position(ball)
            }
            .cornerLabel("Apex \(Int(swing.peakHeight)) ft · \(curveText)")
        }
    }

    private func flag(at p: CGPoint) -> some View {
        let topY = p.y - 22
        return ZStack {
            line(p, CGPoint(x: p.x, y: topY)).stroke(.secondary, lineWidth: 1.5)
            Path { path in
                path.move(to: CGPoint(x: p.x, y: topY))
                path.addLine(to: CGPoint(x: p.x + 12, y: topY + 4))
                path.addLine(to: CGPoint(x: p.x, y: topY + 8))
                path.closeSubpath()
            }
            .fill(.red)
        }
    }

    private var curveText: String {
        let curve = (swing.spinAxis / 45) * max(swing.carryDistance, 1) * 0.5
        if abs(curve) < 1 { return "straight" }
        return String(format: "%.0f yd %@", abs(curve), curve > 0 ? "R" : "L")
    }
}

// MARK: - Down-the-line view (behind the player)

struct DownLineFlightView: View {
    let swing: SwingModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.30
            let bottomY = h * 0.92
            let cx = w / 2
            let p = ShotPath(swing: swing)
            // Pixels of horizon offset per degree of aim.
            let degToPx = (w * 0.32) / 10
            let horizonPt: (Double) -> CGPoint = { deg in CGPoint(x: cx + CGFloat(deg) * degToPx, y: horizon) }
            let ball = CGPoint(x: cx, y: bottomY)

            // Ball-flight projection: recede toward the horizon with a perspective
            // ease (fast then slow), lifting for height and compressing sideways
            // and vertically as it gets farther away.
            let lift = (bottomY - horizon) * 0.5
            let arc: (Double) -> CGPoint = { t in
                let d = p.carry * t
                let recede = 1 - (1 - CGFloat(t)) * (1 - CGFloat(t))   // ease-out
                let baseY = bottomY + (horizon - bottomY) * recede
                let depthShrink = 1 - 0.7 * CGFloat(t)
                let hy = CGFloat(p.height(at: d) / p.maxHeight) * lift * depthShrink
                let lateralPx = CGFloat(p.lateral(at: d) / p.maxLateral) * (w * 0.4) * depthShrink
                return CGPoint(x: cx + lateralPx, y: baseY - hy)
            }

            ZStack {
                // Fairway in perspective.
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.42, y: bottomY))
                    path.addLine(to: CGPoint(x: cx - w * 0.04, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.04, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.42, y: bottomY))
                    path.closeSubpath()
                }
                .fill(.green.opacity(0.18))

                line(CGPoint(x: 0, y: horizon), CGPoint(x: w, y: horizon))
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)

                // Aim lines: target, path, face.
                line(ball, horizonPt(0)).stroke(style: dashed).foregroundStyle(.secondary)
                line(ball, horizonPt(swing.clubPath)).stroke(.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                line(ball, horizonPt(swing.faceAngle)).stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))

                // Ball flight rising away and curving.
                flightPath(carry: 1, point: arc, steps: 60)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Circle().fill(.white).stroke(.orange, lineWidth: 2).frame(width: 11, height: 11).position(ball)
            }
            .legend([(.secondary, "Target"), (.blue, "Path"), (.orange, "Face")])
        }
    }
}

// MARK: - Club face (head-on)

/// Overhead "address" view: looking straight down at the ball, the head sweeps
/// left-to-right through impact while the face opens (before) and closes (after),
/// passing through the set face angle at the ball.
struct ClubFaceView: View {
    let swing: SwingModel
    @Binding var leftHanded: Bool
    @State private var startDate = Date()
    @State private var playing = false

    private let duration = 1.8
    private let closeRate = 24.0   // degrees the face rotates from open to closed through impact

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let ball = CGPoint(x: w * 0.5, y: h * 0.5)
            let span = min(w * 0.40, 150)

            // Right-handed: target on the LEFT, sweep right→left. Left-handed mirrors.
            let targetSign: Double = leftHanded ? 1 : -1   // screen-x direction toward target
            let tiltSign: Double = leftHanded ? -1 : 1      // so +path tilts away from the golfer
            let baseDeg: Double = targetSign > 0 ? 0 : 180  // heading toward the target
            let tangentDeg = baseDeg + tiltSign * swing.clubPath
            let tangent = CGVector(dx: cos(tangentDeg * .pi / 180), dy: sin(tangentDeg * .pi / 180))

            // Hands sit below the ball (the golfer), nudged to the lead side.
            let hands = CGPoint(x: ball.x + CGFloat(targetSign) * 16, y: h * 0.99)

            let pos: (Double) -> CGPoint = { s in
                let along = (2 * s - 1) * Double(span)
                return CGPoint(x: ball.x + CGFloat(along) * tangent.dx,
                               y: ball.y + CGFloat(along) * tangent.dy)
            }
            let headAngle: (Double) -> Double = { s in
                let faceNow = swing.faceAngle + (0.5 - s) * 2 * closeRate
                return baseDeg + tiltSign * faceNow
            }

            ZStack {
                // Swing path line with a travel arrow toward the target.
                line(pos(0), pos(1))
                    .stroke(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                arrowHead(at: pos(1), dir: tangent)
                Text("target").font(.caption2).foregroundStyle(.secondary)
                    .position(x: pos(1).x, y: pos(1).y - 14)

                // Ball.
                Circle().fill(.white).stroke(.secondary, lineWidth: 1)
                    .frame(width: 14, height: 14).position(ball)

                // Shaft (head → hands) and head, swinging through impact.
                TimelineView(.animation(paused: !playing)) { tl in
                    let s = currentS(now: tl.date)
                    let p = pos(s)
                    ZStack {
                        line(p, hands).stroke(.black.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        clubHead(angle: headAngle(s)).position(p)
                    }
                }

                Text(faceLabel)
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)

                Button { leftHanded.toggle() } label: {
                    Label(leftHanded ? "Lefty" : "Righty", systemImage: "figure.golf").font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

                Button {
                    startDate = Date(); playing = true
                } label: {
                    Label("Swing", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(8)
            }
        }
    }

    private var faceLabel: String {
        let f = swing.faceAngle
        let word = f > 1 ? "open" : f < -1 ? "closed" : "square"
        return String(format: "Face %+.1f° (%@)", f, word)
    }

    private func currentS(now: Date) -> Double {
        guard playing else { return 0.5 }   // rest at impact
        let elapsed = now.timeIntervalSince(startDate)
        if elapsed >= duration {
            DispatchQueue.main.async { playing = false }
            return 0.5
        }
        return elapsed / duration
    }

    private func clubHead(angle: Double) -> some View {
        ZStack {
            // Head body (seen from above).
            RoundedRectangle(cornerRadius: 6).fill(Color(.darkGray))
                .frame(width: 24, height: 50)
            // Leading edge = the face, pointing toward the target.
            RoundedRectangle(cornerRadius: 2).fill(.orange)
                .frame(width: 5, height: 48).offset(x: 11)
        }
        .rotationEffect(.degrees(angle))
    }

    private func arrowHead(at p: CGPoint, dir: CGVector) -> some View {
        let ang = atan2(dir.dy, dir.dx)
        return Path { path in
            let size: CGFloat = 9
            for off in [Double.pi - 0.5, Double.pi + 0.5] {
                path.move(to: p)
                path.addLine(to: CGPoint(x: p.x + cos(ang + off) * size, y: p.y + sin(ang + off) * size))
            }
        }
        .stroke(.blue.opacity(0.6), lineWidth: 2)
    }
}

// MARK: - Small shared view helpers

private func line(_ a: CGPoint, _ b: CGPoint) -> Path {
    Path { p in p.move(to: a); p.addLine(to: b) }
}

private func flightPath(carry: Double, point: (Double) -> CGPoint, steps: Int = 60) -> Path {
    Path { p in
        p.move(to: point(0))
        for i in 1...steps {
            p.addLine(to: point(carry * Double(i) / Double(steps)))
        }
    }
}

private extension View {
    func cornerLabel(_ text: String) -> some View {
        overlay(alignment: .topTrailing) {
            Text(text).font(.caption2).foregroundStyle(.secondary).padding(8)
        }
    }

    func legend(_ items: [(Color, String)]) -> some View {
        overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items.indices, id: \.self) { i in
                    HStack(spacing: 4) {
                        Capsule().fill(items[i].0).frame(width: 12, height: 3)
                        Text(items[i].1).font(.system(size: 9))
                    }
                }
            }
            .padding(7)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
    }
}
