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
    case downLine = "Front"
    case top = "Top-down"
    case side = "Side"
    case face = "Face"

    var id: String { rawValue }

    var blurb: String {
        switch self {
        case .top: return "Bird's-eye: blue shows the start line, orange shows the actual flight, and green marks the target window."
        case .downLine: return "Front view: target, path, and face lines show where it all points."
        case .side: return "Side profile: launch angle, apex height, carry, and descent change with loft, attack, speed, and spin."
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
    var yardMarks: [Double] { stride(from: 50, through: carry, by: 50).map { $0 } }

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
                // Sky above the horizon, rough turf below it.
                LinearGradient(
                    colors: [Scenery.skyTop, Scenery.skyHorizon],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: horizon)
                .frame(maxHeight: .infinity, alignment: .top)

                LinearGradient(
                    colors: [Scenery.turfMid, Scenery.turfDeep],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: h - horizon)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Distant trees, softened by haze on the horizon.
                TreeLineShape(seed: 1)
                    .fill(Scenery.treeLine.opacity(0.75))
                    .frame(width: w, height: 14)
                    .position(x: cx, y: horizon - 7)

                HorizonHaze(width: w, horizon: horizon)

                // Fairway receding to the horizon.
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.5, y: bottomY))
                    path.addLine(to: CGPoint(x: cx - w * 0.045, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.045, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.5, y: bottomY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Scenery.fairway, Scenery.fairwayLight],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                perspectiveMowBands(cx: cx, w: w, horizon: horizon, bottomY: bottomY,
                                    bottomHalf: 0.5, topHalf: 0.045)

                // Target line to the vanishing point.
                line(ball, CGPoint(x: cx, y: horizon))
                    .stroke(.white.opacity(0.55), style: dashed)

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
            line(p, CGPoint(x: p.x, y: topY)).stroke(.white.opacity(0.85), lineWidth: 1.5)
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

// MARK: - Side trajectory view

struct SideTrajectoryView: View {
    let swing: SwingModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = ShotPath(swing: swing)
            let left: CGFloat = 24
            let right: CGFloat = 18
            let top: CGFloat = 54
            let groundY = h - 30
            let plotW = max(1, w - left - right)
            let plotH = max(1, groundY - top)

            let point: (Double) -> CGPoint = { distance in
                let x = left + CGFloat(distance / p.carry) * plotW
                let y = groundY - CGFloat(p.height(at: distance) / p.maxHeight) * plotH
                return CGPoint(x: x, y: y)
            }

            let apexDistance = p.carry * p.apexFraction
            let apex = point(apexDistance)
            let landing = point(p.carry)
            let launchGuideEnd = CGPoint(
                x: left + cos(CGFloat(swing.launchAngle) * .pi / 180) * 58,
                y: groundY - sin(CGFloat(swing.launchAngle) * .pi / 180) * 58
            )

            ZStack {
                sideProfileBackground(width: w, height: h, top: top, groundY: groundY)

                TreeLineShape(seed: 3)
                    .fill(Scenery.treeLine.opacity(0.40))
                    .frame(width: w, height: 13)
                    .position(x: w / 2, y: groundY - 6.5)

                HorizonHaze(width: w, horizon: groundY, height: 30)

                ForEach(1..<4) { i in
                    let y = groundY - plotH * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: left, y: y))
                        path.addLine(to: CGPoint(x: w - right, y: y))
                    }
                    .stroke(.secondary.opacity(0.10), lineWidth: 1)
                }

                ForEach(p.yardMarks, id: \.self) { yards in
                    let x = left + CGFloat(yards / p.carry) * plotW
                    Path { path in
                        path.move(to: CGPoint(x: x, y: groundY - 5))
                        path.addLine(to: CGPoint(x: x, y: groundY + 5))
                    }
                    .stroke(.white.opacity(0.30), lineWidth: 1)

                    Text("\(Int(yards))")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.70))
                        .position(x: x, y: groundY + 17)
                }

                Path { path in
                    path.move(to: CGPoint(x: left, y: groundY))
                    path.addLine(to: CGPoint(x: w - right, y: groundY))
                }
                .stroke(.white.opacity(0.40), lineWidth: 1.5)

                Ellipse()
                    .fill(.black.opacity(0.10))
                    .frame(width: 28, height: 7)
                    .position(x: left, y: groundY + 5)

                Ellipse()
                    .fill(.black.opacity(0.11))
                    .frame(width: 34, height: 8)
                    .position(x: landing.x, y: groundY + 5)

                Path { path in
                    path.move(to: CGPoint(x: left, y: groundY))
                    path.addLine(to: launchGuideEnd)
                }
                .stroke(.blue.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                flightPath(carry: p.carry, point: point, steps: 70)
                    .stroke(apexColor.opacity(0.16), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

                flightPath(carry: p.carry, point: point, steps: 70)
                    .stroke(apexColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                ForEach(1..<7) { i in
                    let distance = p.carry * Double(i) / 7
                    let progress = Double(i) / 7
                    let size = 12 - CGFloat(progress) * 5
                    Circle()
                        .fill(apexColor.opacity(0.72 - progress * 0.08))
                        .frame(width: size, height: size)
                        .position(point(distance))
                }

                Path { path in
                    path.move(to: CGPoint(x: apex.x, y: apex.y))
                    path.addLine(to: CGPoint(x: apex.x, y: groundY))
                }
                .stroke(apexColor.opacity(0.45), style: dashed)

                apexMarker(at: apex)

                Circle().fill(.white).stroke(.orange, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .position(x: left, y: groundY)

                Circle()
                    .fill(.orange.opacity(0.18))
                    .frame(width: 26, height: 26)
                    .position(landing)

                Circle()
                    .fill(.orange)
                    .frame(width: 10, height: 10)
                    .position(landing)

                label("Launch \(String(format: "%.1f", swing.launchAngle))°", at: launchGuideEnd, alignment: .topLeading)
                apexLabel(at: apex)
                label("Carry \(Int(swing.carryDistance)) yd", at: landing, alignment: .topTrailing)
            }
        }
    }

    private func sideProfileBackground(width w: CGFloat, height h: CGFloat, top: CGFloat, groundY: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Scenery.skyTop.opacity(0.75), Scenery.skyHorizon],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(0, groundY))
            .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(
                colors: [Scenery.fairway, Scenery.turfMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(0, h - groundY))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var apexCategory: String {
        switch swing.peakHeight {
        case ..<65: return "Low Apex"
        case 105...: return "High Apex"
        default: return "Stock Apex"
        }
    }

    private var apexColor: Color {
        switch swing.peakHeight {
        case ..<65: return .blue
        case 105...: return .purple
        default: return .orange
        }
    }

    private var apexIcon: String {
        switch swing.peakHeight {
        case ..<65: return "arrow.down.circle.fill"
        case 105...: return "arrow.up.circle.fill"
        default: return "target"
        }
    }

    private func apexMarker(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(apexColor.opacity(0.16))
                .frame(width: 42, height: 42)
            Circle()
                .fill(.thinMaterial)
                .frame(width: 28, height: 28)
            Circle()
                .stroke(apexColor, lineWidth: 2)
                .frame(width: 28, height: 28)
            Image(systemName: apexIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(apexColor)
        }
        .position(point)
    }

    private func apexLabel(at point: CGPoint) -> some View {
        Text("\(apexCategory) · \(Int(swing.peakHeight)) ft")
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(apexColor.opacity(0.16), in: Capsule())
            .foregroundStyle(apexColor)
            .position(apexLabelPosition(for: point))
    }

    private func label(_ text: String, at point: CGPoint, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
            .position(labelPosition(for: point, alignment: alignment))
    }

    private func apexLabelPosition(for point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y + 30)
    }

    private func labelPosition(for point: CGPoint, alignment: Alignment) -> CGPoint {
        switch alignment {
        case .topLeading:
            return CGPoint(x: point.x + 32, y: point.y - 10)
        case .topTrailing:
            return CGPoint(x: point.x - 42, y: point.y - 14)
        case .bottom:
            return CGPoint(x: point.x, y: point.y - 16)
        default:
            return point
        }
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
                realisticRangeBackground(width: w, height: h, horizon: horizon, bottomY: bottomY)

                // Distant trees, softened by haze on the horizon.
                TreeLineShape(seed: 2)
                    .fill(Scenery.treeLine.opacity(0.75))
                    .frame(width: w, height: 15)
                    .position(x: cx, y: horizon - 7.5)

                HorizonHaze(width: w, horizon: horizon)

                // Fairway in perspective.
                Path { path in
                    path.move(to: CGPoint(x: cx - w * 0.46, y: bottomY))
                    path.addLine(to: CGPoint(x: cx - w * 0.055, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.055, y: horizon))
                    path.addLine(to: CGPoint(x: cx + w * 0.46, y: bottomY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Scenery.fairway, Scenery.fairwayLight],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                perspectiveMowBands(cx: cx, w: w, horizon: horizon, bottomY: bottomY,
                                    bottomHalf: 0.46, topHalf: 0.055)

                ForEach(1..<6) { i in
                    let t = CGFloat(i) / 6
                    let y = bottomY + (horizon - bottomY) * (1 - pow(1 - t, 2))
                    let halfWidth = w * (0.055 + 0.405 * (1 - t))
                    Path { path in
                        path.move(to: CGPoint(x: cx - halfWidth, y: y))
                        path.addLine(to: CGPoint(x: cx + halfWidth, y: y))
                    }
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                }

                line(CGPoint(x: cx - w * 0.46, y: bottomY), CGPoint(x: cx - w * 0.055, y: horizon))
                    .stroke(.white.opacity(0.30), lineWidth: 1.5)
                line(CGPoint(x: cx + w * 0.46, y: bottomY), CGPoint(x: cx + w * 0.055, y: horizon))
                    .stroke(.white.opacity(0.30), lineWidth: 1.5)

                // Aim lines: target, path, face.
                line(ball, horizonPt(0)).stroke(.white.opacity(0.6), style: dashed)
                line(ball, horizonPt(swing.clubPath)).stroke(.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                line(ball, horizonPt(swing.faceAngle)).stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))

                // Ball flight rising away and curving.
                flightPath(carry: 1, point: arc, steps: 60)
                    .stroke(.orange.opacity(0.16), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

                flightPath(carry: 1, point: arc, steps: 60)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                ForEach(1..<7) { i in
                    let t = Double(i) / 7
                    let size = max(3, 12 - CGFloat(t) * 8)
                    Circle()
                        .fill(.orange.opacity(0.78 - t * 0.06))
                        .frame(width: size, height: size)
                        .position(arc(t))
                }

                perspectiveFlag(at: horizonPt(0), scale: 0.72)

                Ellipse()
                    .fill(.black.opacity(0.13))
                    .frame(width: 26, height: 7)
                    .position(x: ball.x, y: ball.y + 5)

                Circle()
                    .fill(.white)
                    .stroke(.orange, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .position(ball)
            }
            .legend([(.secondary, "Target"), (.blue, "Path"), (.orange, "Face")])
        }
    }

    private func realisticRangeBackground(width w: CGFloat, height h: CGFloat, horizon: CGFloat, bottomY: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Scenery.skyTop, Scenery.skyHorizon],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(0, horizon))
            .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(
                colors: [Scenery.turfMid, Scenery.turfDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(0, h - horizon))
            .frame(maxHeight: .infinity, alignment: .bottom)

            Path { path in
                path.move(to: CGPoint(x: 0, y: bottomY))
                path.addLine(to: CGPoint(x: w * 0.42, y: horizon))
                path.addLine(to: CGPoint(x: 0, y: horizon))
                path.closeSubpath()
            }
            .fill(Scenery.turfDeep.opacity(0.5))

            Path { path in
                path.move(to: CGPoint(x: w, y: bottomY))
                path.addLine(to: CGPoint(x: w * 0.58, y: horizon))
                path.addLine(to: CGPoint(x: w, y: horizon))
                path.closeSubpath()
            }
            .fill(Scenery.turfDeep.opacity(0.5))
        }
    }

    private func perspectiveFlag(at point: CGPoint, scale: CGFloat) -> some View {
        let poleHeight = 28 * scale
        let flagWidth = 16 * scale
        return ZStack {
            line(point, CGPoint(x: point.x, y: point.y - poleHeight))
                .stroke(.white.opacity(0.85), lineWidth: 1.4)
            Path { path in
                path.move(to: CGPoint(x: point.x, y: point.y - poleHeight))
                path.addLine(to: CGPoint(x: point.x + flagWidth, y: point.y - poleHeight + 4 * scale))
                path.addLine(to: CGPoint(x: point.x, y: point.y - poleHeight + 8 * scale))
                path.closeSubpath()
            }
            .fill(.red.opacity(0.90))
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
            let rawBodyDir = CGVector(dx: -tangent.dy, dy: tangent.dx)
            let bodyDir = rawBodyDir.dy >= 0
                ? rawBodyDir
                : CGVector(dx: -rawBodyDir.dx, dy: -rawBodyDir.dy)

            // Hands sit on the body side of the ball. Rotating this vector with
            // club path makes the setup look like the player aimed their feet/body.
            let handsDistance = min(h * 0.46, 150)
            let hands = CGPoint(
                x: ball.x + bodyDir.dx * handsDistance + tangent.dx * CGFloat(targetSign) * 14,
                y: ball.y + bodyDir.dy * handsDistance + tangent.dy * CGFloat(targetSign) * 14
            )

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
                faceViewBackground(width: w, height: h, ball: ball)

                setupGuides(ball: ball, tangent: tangent, bodyDir: bodyDir, pathAngle: tangentDeg, width: w, height: h)

                impactZone(at: ball, width: min(w * 0.62, 210), angle: tangentDeg)

                // Swing path line with a travel arrow toward the target.
                line(pos(0), pos(1))
                    .stroke(Theme.path.opacity(0.42), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                arrowHead(at: pos(1), dir: tangent)
                Text("target").font(.caption2).foregroundStyle(.white.opacity(0.85))
                    .position(x: pos(1).x, y: pos(1).y - 14)

                // Ball.
                ballTopView(at: ball)

                // Shaft (head → hands) and head, swinging through impact.
                TimelineView(.animation(paused: !playing)) { tl in
                    let s = currentS(now: tl.date)
                    let p = pos(s)
                    ZStack {
                        shaft(from: hoselPoint(at: p, angle: headAngle(s)), to: hands)
                        realisticClubHead(angle: headAngle(s), opacity: 1)
                            .position(p)
                        handsMarker(at: hands)
                    }
                }

                Text(faceLabel)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)

                handednessControl
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

    private var handednessControl: some View {
        HStack(spacing: 2) {
            handednessButton(title: "Right-handed", isSelected: !leftHanded) {
                leftHanded = false
            }
            handednessButton(title: "Left-handed", isSelected: leftHanded) {
                leftHanded = true
            }
        }
        .padding(3)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func handednessButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Theme.path : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
        realisticClubHead(angle: angle, opacity: 1)
    }

    private func faceViewBackground(width w: CGFloat, height h: CGFloat, ball: CGPoint) -> some View {
        ZStack {
            LinearGradient(
                colors: [Scenery.fairway, Scenery.fairwayLight, Scenery.fairway],
                startPoint: .top,
                endPoint: .bottom
            )

            GrassTexture(bladeCount: 90, tint: Scenery.turfDeep.opacity(0.5))

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.30))
                .frame(width: min(w * 0.82, 300), height: min(h * 0.56, 170))
                .position(x: ball.x, y: ball.y + 10)

            ForEach(0..<5) { i in
                let y = ball.y - 76 + CGFloat(i) * 36
                line(CGPoint(x: w * 0.12, y: y), CGPoint(x: w * 0.88, y: y))
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            }
        }
    }

    private func setupGuides(ball: CGPoint, tangent: CGVector, bodyDir: CGVector, pathAngle: Double, width: CGFloat, height: CGFloat) -> some View {
        let stanceCenter = CGPoint(
            x: ball.x + bodyDir.dx * min(height * 0.34, 110),
            y: ball.y + bodyDir.dy * min(height * 0.34, 110)
        )
        let shoulderCenter = CGPoint(
            x: ball.x + bodyDir.dx * min(height * 0.21, 72),
            y: ball.y + bodyDir.dy * min(height * 0.21, 72)
        )
        let stanceHalf: CGFloat = min(width * 0.19, 72)
        let footA = CGPoint(x: stanceCenter.x - tangent.dx * stanceHalf, y: stanceCenter.y - tangent.dy * stanceHalf)
        let footB = CGPoint(x: stanceCenter.x + tangent.dx * stanceHalf, y: stanceCenter.y + tangent.dy * stanceHalf)
        let shoulderA = CGPoint(x: shoulderCenter.x - tangent.dx * stanceHalf * 0.72, y: shoulderCenter.y - tangent.dy * stanceHalf * 0.72)
        let shoulderB = CGPoint(x: shoulderCenter.x + tangent.dx * stanceHalf * 0.72, y: shoulderCenter.y + tangent.dy * stanceHalf * 0.72)

        return ZStack {
            line(footA, footB)
                .stroke(.white.opacity(0.30), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            line(shoulderA, shoulderB)
                .stroke(.white.opacity(0.20), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            footMarker(at: footA, angle: pathAngle)
            footMarker(at: footB, angle: pathAngle)
        }
    }

    private func footMarker(at point: CGPoint, angle: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.22))
            .overlay {
                Capsule().stroke(.white.opacity(0.28), lineWidth: 1)
            }
            .frame(width: 48, height: 16)
            .rotationEffect(.degrees(angle))
            .position(point)
    }

    private func impactZone(at ball: CGPoint, width: CGFloat, angle: Double) -> some View {
        ZStack {
            Capsule()
                .fill(Theme.face.opacity(0.10))
                .frame(width: width, height: 34)
            Capsule()
                .stroke(Theme.face.opacity(0.22), style: StrokeStyle(lineWidth: 1))
                .frame(width: width, height: 34)
            Capsule()
                .fill(.secondary.opacity(0.16))
                .frame(width: width, height: 1)
        }
        .position(ball)
        .rotationEffect(.degrees(angle), anchor: .center)
    }

    private func ballTopView(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .overlay { Circle().stroke(.secondary.opacity(0.45), lineWidth: 1) }
                .frame(width: 17, height: 17)
            Circle()
                .fill(.secondary.opacity(0.18))
                .frame(width: 2.5, height: 2.5)
                .offset(x: -3, y: -2)
            Circle()
                .fill(.secondary.opacity(0.15))
                .frame(width: 2, height: 2)
                .offset(x: 3, y: 2)
        }
        .position(point)
    }

    /// Driver head seen from above: carbon crown, curved face band on the leading
    /// edge, alignment mark, and a hosel at the heel corner. Drawn heel-down
    /// (right-handed is mirrored) and shifted back so the face sits tangent to
    /// the ball when positioned on it; `angle` rotates about that contact point.
    private func realisticClubHead(angle: Double, opacity: Double) -> some View {
        ZStack {
            DriverCrownShape()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.44), Color(white: 0.30), Color(white: 0.13)],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
            DriverCrownShape()
                .stroke(.white.opacity(0.30), lineWidth: 1)

            // Sheen across the crown.
            DriverCrownShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            // Alignment mark just behind the face.
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 3.5, height: 3.5)
                .offset(x: 12)

            // Face band along the leading edge.
            FaceEdgeShape()
                .stroke(Theme.face, style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Hosel at the heel-front corner.
            Circle()
                .fill(Color(white: 0.55))
                .overlay { Circle().stroke(.white.opacity(0.45), lineWidth: 1) }
                .frame(width: 9, height: 9)
                .offset(x: 20.5, y: 17.5)
        }
        .frame(width: 44, height: 48)
        .compositingGroup()
        .opacity(opacity)
        .scaleEffect(x: 1, y: leftHanded ? 1 : -1)
        .offset(x: -33)
        .rotationEffect(.degrees(angle))
    }

    /// Screen position of the hosel for a head pivoting about `p` at `angle`,
    /// matching the hosel drawn in `realisticClubHead`.
    private func hoselPoint(at p: CGPoint, angle: Double) -> CGPoint {
        let local = CGVector(dx: -12.5, dy: leftHanded ? 17.5 : -17.5)
        let a = CGFloat(angle) * .pi / 180
        return CGPoint(
            x: p.x + local.dx * cos(a) - local.dy * sin(a),
            y: p.y + local.dx * sin(a) + local.dy * cos(a)
        )
    }

    private func shaft(from hosel: CGPoint, to hands: CGPoint) -> some View {
        ZStack {
            line(hosel, hands)
                .stroke(.secondary.opacity(0.58), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            line(hosel, hands)
                .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }
    }

    private func handsMarker(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: 18, height: 18)
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
                .frame(width: 18, height: 18)
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 18, height: 5)
        }
        .position(point)
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

/// Top-down outline of a driver crown: face along the trailing (maxX) edge,
/// toe at minY, rounded pear-shaped body tapering to the heel at maxY.
private struct DriverCrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
        }
        var p = Path()
        p.move(to: pt(1.0, 0.86))
        // Leading edge (heel to toe) with a slight bulge.
        p.addQuadCurve(to: pt(1.0, 0.14), control: pt(1.07, 0.50))
        // Around the toe and back of the crown.
        p.addCurve(to: pt(0.05, 0.40), control1: pt(0.92, -0.08), control2: pt(0.22, -0.02))
        // Back to the heel.
        p.addCurve(to: pt(0.58, 0.96), control1: pt(-0.04, 0.72), control2: pt(0.24, 1.00))
        // Heel taper into the hosel.
        p.addQuadCurve(to: pt(1.0, 0.86), control: pt(0.88, 0.94))
        p.closeSubpath()
        return p
    }
}

/// The leading-edge curve of `DriverCrownShape`, stroked as the face band.
private struct FaceEdgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY + 0.84 * rect.height))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 0.16 * rect.height),
            control: CGPoint(x: rect.maxX + 0.07 * rect.width, y: rect.midY)
        )
        return p
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

/// Alternating mow bands on a perspective fairway whose straight edges run
/// from `cx ± bottomHalf·w` at `bottomY` to `cx ± topHalf·w` at `horizon`,
/// spaced with the same ease-out recede the flight projections use.
private func perspectiveMowBands(cx: CGFloat, w: CGFloat, horizon: CGFloat, bottomY: CGFloat,
                                 bottomHalf: CGFloat, topHalf: CGFloat) -> some View {
    let bands = 8
    let y: (CGFloat) -> CGFloat = { t in bottomY + (horizon - bottomY) * (1 - pow(1 - t, 2)) }
    let half: (CGFloat) -> CGFloat = { yy in
        let f = (yy - horizon) / (bottomY - horizon)
        return w * (topHalf + (bottomHalf - topHalf) * f)
    }
    return Path { p in
        for k in stride(from: 0, to: bands, by: 2) {
            let y0 = y(CGFloat(k) / CGFloat(bands))
            let y1 = y(CGFloat(k + 1) / CGFloat(bands))
            p.move(to: CGPoint(x: cx - half(y0), y: y0))
            p.addLine(to: CGPoint(x: cx - half(y1), y: y1))
            p.addLine(to: CGPoint(x: cx + half(y1), y: y1))
            p.addLine(to: CGPoint(x: cx + half(y0), y: y0))
            p.closeSubpath()
        }
    }
    .fill(.white.opacity(0.06))
}

#Preview("Front") {
    var swing = SwingModel()
    swing.faceAngle = 3
    swing.clubPath = -2
    return FrontFlightView(swing: swing)
        .frame(height: 300)
        .padding()
}

#Preview("Down the Line") {
    var swing = SwingModel()
    swing.faceAngle = 3
    swing.clubPath = -2
    return DownLineFlightView(swing: swing)
        .frame(height: 300)
        .padding()
}

#Preview("Side") {
    SideTrajectoryView(swing: SwingModel())
        .frame(height: 300)
        .padding()
}

#Preview("Club Face") {
    @Previewable @State var leftHanded = false
    var swing = SwingModel()
    swing.faceAngle = 6
    return ClubFaceView(swing: swing, leftHanded: $leftHanded)
        .frame(height: 300)
        .padding()
}

#Preview("Club Face (Lefty)") {
    @Previewable @State var leftHanded = true
    ClubFaceView(swing: SwingModel(), leftHanded: $leftHanded)
        .frame(height: 300)
        .padding()
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
