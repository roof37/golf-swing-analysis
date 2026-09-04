//
//  SwingStage.swift
//  golf swing analysis
//
//  The motion-analysis stage. The figure lives in real 3D world space
//  (meters; +x toward the target, +y up, +z out toward the ball line) and is
//  rendered through four orthographic cameras:
//
//    • Face-On — the classic front view. Pelvis/thorax rotation reads as
//      foreshortening of the bars, the way a camera would actually see it.
//    • Down the Line — from behind the ball looking at the target. This is
//      where the swing plane, and an over-the-top plane shift, are visible.
//
//  The clubhead trail is persistent for the whole swing and colored by
//  clubhead speed, so *where the club peaked* is readable at a glance: a
//  cast peaks before the ball, a good sequence peaks at it. An optional
//  ghost overlays the Tour Move pattern for comparison.
//

import SwiftUI
import simd

enum StageViewAngle: String, CaseIterable, Identifiable {
    case spatial = "3D"
    case faceOn = "Face-On"
    case downTheLine = "Down the Line"
    case top = "Top"
    var id: String { rawValue }
}

/// What the stage is drawing: the whole golfer, or just the club and how it
/// meets the ball. Both subjects render through the same `StageViewAngle`
/// cameras.
enum StageSubject: String, CaseIterable, Identifiable {
    case body = "Body"
    case club = "Club"
    var id: String { rawValue }
}

enum SwingStagePresentation {
    case analysis
    case motion
}

/// Pure geometry for the Club-focus overlay, split out so the parts that are
/// just math can be unit-tested without a `Canvas`.
enum ClubFocusGeometry {

    /// Unit world-space direction the clubhead travels through impact, for the
    /// ground arrow. World frame matches `SwingPlane`: +x toward the target,
    /// +y up, +z from the golfer out toward the ball line. `path` (deg,
    /// + = in-to-out / right of target) is the heading about vertical; `attack`
    /// (deg, + = up) is the vertical tilt. Recoverable with the same `atan2`
    /// convention `SwingPlane.clubPath` / `attackAngle` use.
    static func groundArrowVector(path: Double, attack: Double) -> SIMD3<Double> {
        let p = path * .pi / 180
        let a = attack * .pi / 180
        return SIMD3(cos(a) * cos(p), sin(a), cos(a) * sin(p))
    }

    /// World heel→toe axis of the face: the ball-line axis (+z) yawed about
    /// vertical by the face angle (deg, + = open / pointed right).
    static func faceEdgeAxis(faceAngle: Double) -> SIMD3<Double> {
        let f = faceAngle * .pi / 180
        return SIMD3(-sin(f), 0, cos(f))
    }

    /// World face normal — where the face points: down the target line (+x)
    /// yawed by the face angle and pitched back (up) by the dynamic loft.
    static func faceNormal(faceAngle: Double, dynamicLoft: Double) -> SIMD3<Double> {
        let f = faceAngle * .pi / 180
        let l = dynamicLoft * .pi / 180
        return SIMD3(cos(l) * cos(f), sin(l), cos(l) * sin(f))
    }
}

// MARK: - World-space figure

/// World-space joint positions for one pose. Body joints come from the pose's
/// rotation channels; hands and clubhead live on the inclined swing plane.
struct SwingFigure3D {
    typealias V3 = SIMD3<Double>

    let leadFoot, trailFoot, leadKnee, trailKnee: V3
    let pelvis, leadHip, trailHip: V3
    let thorax, leadShoulder, trailShoulder, head: V3
    let hands, clubhead: V3

    /// Proportions (m). The hub sits at mid-shoulder height; arm + club reach
    /// is scaled so the delivered clubhead meets the ground at the ball.
    private static let hubHeight = 1.34
    private static let ballHeight = 0.02

    static func hub(for pose: GolferPose) -> V3 {
        let sway = (pose.weight - 0.5) * 0.28
        return V3(sway - pose.spine * 0.006, hubHeight, 0.10)
    }

    /// Render-space arm/club radii: physical segment lengths, uniformly scaled
    /// so full extension down the plane reaches from the hub to the ball.
    static func reach(for club: Biomechanics.Club, tilt: Double) -> (arm: Double, club: Double) {
        let arm = SwingEngine.armSegmentLength
        let shaft = club.pendulumLength
        let scale = (hubHeight - ballHeight) / (sin(tilt) * (arm + shaft))
        return (arm * scale, shaft * scale)
    }

    /// Clubhead world position alone — cheap enough to run per frame for the
    /// full-swing trail.
    static func clubhead(pose: GolferPose, club: Biomechanics.Club, plane: SwingPlane) -> V3 {
        let basis = plane.basis(at: pose.progress)
        let r = reach(for: club, tilt: plane.tilt)
        let a = pose.armAngle * .pi / 180
        let c = pose.clubAngle * .pi / 180
        let hub = hub(for: pose)
        let hands = hub + r.arm * (sin(a) * basis.u - cos(a) * basis.v)
        return hands + r.club * (sin(c) * basis.u - cos(c) * basis.v)
    }

    init(pose: GolferPose, club: Biomechanics.Club, plane: SwingPlane) {
        let sway = (pose.weight - 0.5) * 0.28
        let spineShift = pose.spine * 0.006

        leadFoot = V3(0.30, 0, 0)
        trailFoot = V3(-0.30, 0, 0)
        pelvis = V3(sway, 0.94, 0.02)

        // Rotation about the vertical axis: opening pulls the lead side back
        // (away from the ball line) and swings the trail side toward it.
        func rotated(_ degrees: Double) -> V3 {
            let r = degrees * .pi / 180
            return V3(cos(r), 0, -sin(r))
        }
        let hipDir = rotated(pose.hip)
        leadHip = pelvis + 0.15 * hipDir
        trailHip = pelvis - 0.15 * hipDir

        leadKnee = V3(leadFoot.x * 0.6 + leadHip.x * 0.4, 0.48, 0.06)
        trailKnee = V3(trailFoot.x * 0.6 + trailHip.x * 0.4, 0.48, 0.06)

        // Side bend leans the upper body away from the target.
        thorax = V3(sway - spineShift, Self.hubHeight, 0.10)
        let shoulderDir = rotated(pose.shoulder)
        leadShoulder = thorax + 0.19 * shoulderDir
        trailShoulder = thorax - 0.19 * shoulderDir
        head = thorax + V3(-pose.spine * 0.004, 0.245, 0.02)

        let basis = plane.basis(at: pose.progress)
        let r = Self.reach(for: club, tilt: plane.tilt)
        let a = pose.armAngle * .pi / 180
        let c = pose.clubAngle * .pi / 180
        hands = thorax + r.arm * (sin(a) * basis.u - cos(a) * basis.v)
        clubhead = hands + r.club * (sin(c) * basis.u - cos(c) * basis.v)
    }
}

// MARK: - Orthographic cameras

private struct StageCamera {
    let angle: StageViewAngle
    let scale: CGFloat
    let center2D: CGPoint      // view-plane coords at screen center
    let screenCenter: CGPoint

    /// World point → view-plane 2D (pre-scale). Face-on flips x so the
    /// target is screen-left; down-the-line looks from behind the golfer
    /// toward the target with the ball line to the right.
    static func viewPoint(_ p: SIMD3<Double>, angle: StageViewAngle) -> CGPoint {
        switch angle {
        case .spatial: return CGPoint(x: -0.78 * p.x + 0.52 * p.z, y: p.y + 0.20 * p.x + 0.10 * p.z)
        case .faceOn: return CGPoint(x: -p.x, y: p.y)
        case .downTheLine: return CGPoint(x: p.z, y: p.y)
        case .top: return CGPoint(x: -p.x, y: -p.z + 0.08 * p.y)
        }
    }

    /// Depth toward the camera (bigger = nearer), for subtle weight cues.
    static func depth(_ p: SIMD3<Double>, angle: StageViewAngle) -> Double {
        switch angle {
        case .spatial: return 0.48 * p.x + 0.72 * p.z + 0.18 * p.y
        case .faceOn: return p.z
        case .downTheLine: return -p.x
        case .top: return p.y
        }
    }

    /// Fit the camera so every given world point stays in frame.
    init(fitting worldPoints: [SIMD3<Double>], angle: StageViewAngle, size: CGSize) {
        self.angle = angle
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in worldPoints {
            let v = Self.viewPoint(p, angle: angle)
            minX = min(minX, v.x); maxX = max(maxX, v.x)
            minY = min(minY, v.y); maxY = max(maxY, v.y)
        }
        let spanX = max(maxX - minX, 0.5), spanY = max(maxY - minY, 0.5)
        scale = min(size.width / spanX, size.height / spanY) * 0.88
        center2D = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func project(_ p: SIMD3<Double>) -> CGPoint {
        let v = Self.viewPoint(p, angle: angle)
        return CGPoint(x: screenCenter.x + (v.x - center2D.x) * scale,
                       y: screenCenter.y - (v.y - center2D.y) * scale)
    }

    func depth(_ p: SIMD3<Double>) -> Double { Self.depth(p, angle: angle) }
}

// MARK: - Stage view

struct SwingStageView: View {
    let pose: GolferPose
    let bio: Biomechanics
    var viewAngle: StageViewAngle = .faceOn
    var subject: StageSubject = .body
    var showGhost: Bool = false
    var presentation: SwingStagePresentation = .analysis

    /// The comparison body: the Tour Move pattern swinging the same club.
    static func ghostBody(club: Biomechanics.Club) -> Biomechanics {
        var ghost = Biomechanics()
        ghost.club = club
        if let tour = BodyFault.library.first(where: { $0.name == "Tour Move" }) {
            tour.apply(to: &ghost)
        }
        return ghost
    }

    var body: some View {
        Canvas { ctx, size in
            let mech = bio.mechanics
            let plane = mech.plane
            let output = mech.timeline
            let club = bio.club

            // Full-swing clubhead trail in world space.
            let trailPoints = output.frames.map {
                SwingFigure3D.clubhead(pose: $0, club: club, plane: plane)
            }
            let ball = SwingFigure3D.clubhead(
                pose: output.pose(at: SwingEngine.Output.impactProgress), club: club, plane: plane)

            let ghost: (bio: Biomechanics, trail: [SIMD3<Double>], maxSpeed: Double)? = showGhost ? {
                let gBio = Self.ghostBody(club: club)
                let gMech = gBio.mechanics
                let gTrail = gMech.timeline.frames.map {
                    SwingFigure3D.clubhead(pose: $0, club: club, plane: gMech.plane)
                }
                return (gBio, gTrail, gMech.timeline.headSpeeds.max() ?? 1)
            }() : nil

            let figure = SwingFigure3D(pose: pose, club: club, plane: plane)
            var fitPoints: [SIMD3<Double>]
            switch subject {
            case .body:
                fitPoints = trailPoints
                fitPoints.append(contentsOf: [figure.leadFoot, figure.trailFoot, figure.head, ball])
                if let ghost { fitPoints.append(contentsOf: ghost.trail) }
            case .club:
                if presentation == .motion {
                    // Follow the current club and its short history so the club
                    // fills the phone viewport throughout the swing.
                    let last = min(trailPoints.count - 1,
                                   max(1, Int(pose.progress * Double(trailPoints.count - 1))))
                    let first = max(0, last - max(8, trailPoints.count / 9))
                    fitPoints = Array(trailPoints[first...last])
                    fitPoints.append(contentsOf: [figure.hands, figure.clubhead, ball])
                } else {
                    let dx = 0.62, up = 0.52, down = 0.18, dz = 0.62
                    fitPoints = [
                        ball + SIMD3<Double>( dx,  up, 0),
                        ball + SIMD3<Double>(-dx, -down, 0),
                        ball + SIMD3<Double>(  0, -down,  dz),
                        ball + SIMD3<Double>(  0,  up, -dz),
                        figure.clubhead,
                        figure.hands
                    ]
                }
            }
            let camera = StageCamera(fitting: fitPoints, angle: viewAngle, size: size)

            if presentation == .motion {
                drawMotionBackdrop(&ctx, camera: camera, size: size, ball: ball)
            } else {
                drawBackdrop(&ctx, camera: camera, size: size, plane: plane, ball: ball, subject: subject)
            }
            if let ghost {
                drawGhost(&ctx, camera: camera, ghost: (ghost.bio, ghost.trail),
                          progress: pose.progress, club: club,
                          recentOnly: presentation == .motion)
            }
            // With a ghost on stage, heat is normalized to the faster swing —
            // a leaky sequence visibly never reaches full temperature.
            let normSpeed = max(output.headSpeeds.max() ?? 1, ghost?.maxSpeed ?? 1)
            drawTrail(&ctx, camera: camera, points: trailPoints,
                      speeds: output.headSpeeds, normalizeTo: normSpeed, ball: ball,
                      recentOnly: presentation == .motion)
            switch subject {
            case .body:
                drawFigure(&ctx, camera: camera, figure: figure)
            case .club:
                drawClubFocus(&ctx, camera: camera, figure: figure, impact: mech.impact,
                              lowPointPastBall: mech.diagnostics.lowPointPastBall,
                              trail: trailPoints, ball: ball,
                              showsAnnotations: presentation == .analysis)
            }
        }
        .background(Color(.systemBackground).opacity(0.50), in: RoundedRectangle(cornerRadius: Theme.insetRadius))
        .accessibilityLabel("Motion analysis: \(subject.rawValue) subject, \(viewAngle.rawValue) view, with a time-aware clubhead trail")
    }

    // MARK: Backdrop

    private func drawMotionBackdrop(_ ctx: inout GraphicsContext, camera: StageCamera,
                                    size: CGSize, ball: SIMD3<Double>) {
        let groundY = camera.project(SIMD3(0, 0, 0)).y
        var ground = Path()
        ground.move(to: CGPoint(x: 12, y: groundY))
        ground.addLine(to: CGPoint(x: size.width - 12, y: groundY))
        ctx.stroke(ground, with: .color(.secondary.opacity(0.22)), lineWidth: 1)
    }

    private func drawBackdrop(_ ctx: inout GraphicsContext, camera: StageCamera,
                              size: CGSize, plane: SwingPlane, ball: SIMD3<Double>,
                              subject: StageSubject) {
        let groundY = camera.project(SIMD3(0, 0, 0)).y

        var ground = Path()
        ground.move(to: CGPoint(x: 10, y: groundY))
        ground.addLine(to: CGPoint(x: size.width - 10, y: groundY))
        ctx.stroke(ground, with: .color(.secondary.opacity(0.22)), lineWidth: 1.25)

        let ballPoint = camera.project(ball)

        switch viewAngle {
        case .spatial:
            // Two ground-plane axes make the isometric projection readable.
            var target = Path()
            target.move(to: camera.project(ball - SIMD3<Double>(0.45, 0, 0)))
            target.addLine(to: camera.project(ball + SIMD3<Double>(0.65, 0, 0)))
            ctx.stroke(target, with: .color(Theme.path.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            ctx.draw(Text("TARGET").font(.system(size: 7, weight: .semibold)).foregroundStyle(.secondary),
                     at: camera.project(ball + SIMD3<Double>(0.72, 0, 0)))
        case .faceOn:
            // Stance center reference.
            var center = Path()
            center.move(to: CGPoint(x: camera.project(SIMD3(0, 2.1, 0)).x, y: size.height * 0.08))
            center.addLine(to: CGPoint(x: camera.project(SIMD3(0, 0, 0)).x, y: groundY))
            ctx.stroke(center, with: .color(.secondary.opacity(0.10)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            // Target direction along the ground. The Club subject draws its own
            // (bolder) path arrow from the ball, so this would only double up.
            if subject == .body {
                let arrowY = groundY + 9
                var arrow = Path()
                arrow.move(to: CGPoint(x: ballPoint.x - 14, y: arrowY))
                arrow.addLine(to: CGPoint(x: ballPoint.x - 44, y: arrowY))
                arrow.move(to: CGPoint(x: ballPoint.x - 38, y: arrowY - 4))
                arrow.addLine(to: CGPoint(x: ballPoint.x - 44, y: arrowY))
                arrow.addLine(to: CGPoint(x: ballPoint.x - 38, y: arrowY + 4))
                ctx.stroke(arrow, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                ctx.draw(Text("TARGET").font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.65)),
                         at: CGPoint(x: ballPoint.x - 66, y: arrowY))
            }

        case .downTheLine:
            // The delivery plane through the ball — and, when the transition
            // shifted the club, the backswing plane it left behind.
            func planeLine(direction: Double) -> Path {
                let basis = SwingPlane.basis(tilt: plane.tilt, direction: direction)
                let top = ball + 2.3 * basis.v
                var p = Path()
                p.move(to: camera.project(ball))
                p.addLine(to: camera.project(top))
                return p
            }
            let shifted = abs(plane.backswingDegrees - plane.deliveryDegrees) > 2.5
            if shifted {
                ctx.stroke(planeLine(direction: plane.backswingDirection),
                           with: .color(.secondary.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 1.25, dash: [5, 6]))
            }
            let deliveryColor: Color = shifted && plane.deliveryDirection < plane.backswingDirection
                ? Theme.bad.opacity(0.55) : Theme.path.opacity(0.45)
            ctx.stroke(planeLine(direction: plane.deliveryDirection),
                       with: .color(deliveryColor),
                       style: StrokeStyle(lineWidth: 1.25, dash: [5, 6]))
            if shifted {
                let basis = SwingPlane.basis(tilt: plane.tilt, direction: plane.deliveryDirection)
                let labelAt = camera.project(ball + 1.9 * basis.v)
                ctx.draw(Text("DOWNSWING PLANE").font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(deliveryColor),
                         at: CGPoint(x: labelAt.x, y: labelAt.y - 9))
            }
            if subject == .body {
                ctx.draw(Text("TARGET ⊙").font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.65)),
                         at: CGPoint(x: ballPoint.x, y: groundY + 10))
            }
        case .top:
            var target = Path()
            target.move(to: camera.project(ball - SIMD3<Double>(0.55, 0, 0)))
            target.addLine(to: camera.project(ball + SIMD3<Double>(0.75, 0, 0)))
            ctx.stroke(target, with: .color(Theme.path.opacity(0.38)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            ctx.draw(Text("TARGET LINE").font(.system(size: 7, weight: .semibold)).foregroundStyle(.secondary),
                     at: camera.project(ball + SIMD3<Double>(0.65, 0, 0)))
        }
    }

    // MARK: Ghost overlay

    private func drawGhost(_ ctx: inout GraphicsContext, camera: StageCamera,
                           ghost: (bio: Biomechanics, trail: [SIMD3<Double>]), progress: Double,
                           club: Biomechanics.Club, recentOnly: Bool = false) {
        var arc = Path()
        let last = min(ghost.trail.count - 1, max(1, Int(progress * Double(ghost.trail.count - 1))))
        let first = recentOnly ? max(0, last - max(8, ghost.trail.count / 9)) : 0
        for i in first...last {
            let p = ghost.trail[i]
            let point = camera.project(p)
            if i == first { arc.move(to: point) } else { arc.addLine(to: point) }
        }
        ctx.stroke(arc, with: .color(.secondary.opacity(0.16)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Ghost club at the same moment of the swing; no body figure appears
        // in the club-centric instrument view.
        let gMech = ghost.bio.mechanics
        let gPose = gMech.timeline.pose(at: progress)
        let gFigure = SwingFigure3D(pose: gPose, club: club, plane: gMech.plane)
        var limbs = Path()
        limbs.move(to: camera.project(gFigure.hands))
        limbs.addLine(to: camera.project(gFigure.clubhead))
        ctx.stroke(limbs, with: .color(.secondary.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        let headAt = camera.project(gFigure.clubhead)
        ctx.fill(Circle().path(in: CGRect(x: headAt.x - 3, y: headAt.y - 3, width: 6, height: 6)),
                 with: .color(.secondary.opacity(0.40)))
    }

    // MARK: Speed-colored trail

    private func trailColor(fraction: Double) -> Color {
        // Cool → hot with speed (path blue into face orange).
        let f = max(0, min(1, fraction))
        return Color(red: 0.30 + (1.00 - 0.30) * f,
                     green: 0.52 + (0.55 - 0.52) * f,
                     blue: 0.95 + (0.15 - 0.95) * f)
    }

    private func drawTrail(_ ctx: inout GraphicsContext, camera: StageCamera,
                           points: [SIMD3<Double>], speeds: [Double],
                           normalizeTo maxSpeed: Double, ball: SIMD3<Double>,
                           recentOnly: Bool = false) {
        guard points.count > 2 else { return }
        let screen = points.map(camera.project)

        // Future motion is visible as a quiet dashed prediction.
        let norm = max(maxSpeed, 1)
        let lastIndex = max(1, min(screen.count - 1, Int(pose.progress * Double(screen.count - 1))))
        if !recentOnly && lastIndex < screen.count - 1 {
            var future = Path()
            future.move(to: screen[lastIndex])
            for p in screen[(lastIndex + 1)...] { future.addLine(to: p) }
            ctx.stroke(future, with: .color(.secondary.opacity(0.15)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
        }

        // Traveled motion fades with age. Speed still modulates thickness,
        // while temporal proximity makes the current position unmistakable.
        let sand = Color(red: 0.67, green: 0.52, blue: 0.30)
        let firstVisible = recentOnly ? max(1, lastIndex - max(8, screen.count / 9)) : 1
        for i in firstVisible...lastIndex {
            let f = speeds[i] / norm
            let visibleCount = max(lastIndex - firstVisible + 1, 1)
            let age = Double(lastIndex - i) / Double(visibleCount)
            let recency = 1 - age
            var seg = Path()
            seg.move(to: screen[i - 1])
            seg.addLine(to: screen[i])
            ctx.stroke(seg, with: .color(sand.opacity(0.12 + 0.76 * recency)),
                       style: StrokeStyle(lineWidth: 1.0 + 1.5 * f + 1.2 * recency, lineCap: .round))
        }

        // A small chevron integrated into the trail communicates direction.
        if lastIndex >= 2 {
            let a = screen[lastIndex - 1], b = screen[lastIndex]
            let dx = b.x - a.x, dy = b.y - a.y
            let length = max(hypot(dx, dy), 1)
            let ux = dx / length, uy = dy / length
            var chevron = Path()
            chevron.move(to: CGPoint(x: b.x - ux * 8 - uy * 4, y: b.y - uy * 8 + ux * 4))
            chevron.addLine(to: b)
            chevron.addLine(to: CGPoint(x: b.x - ux * 8 + uy * 4, y: b.y - uy * 8 - ux * 4))
            ctx.stroke(chevron, with: .color(sand.opacity(0.92)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }

        // The ball, sitting exactly where the simulated head meets it.
        let ballAt = camera.project(ball)
        let ballRect = CGRect(x: ballAt.x - 4, y: ballAt.y - 4, width: 8, height: 8)
        ctx.fill(Circle().path(in: ballRect), with: .color(.white))
        ctx.stroke(Circle().path(in: ballRect), with: .color(.secondary.opacity(0.65)), lineWidth: 1)
    }

    // MARK: Figure

    private func drawFigure(_ ctx: inout GraphicsContext, camera: StageCamera, figure: SwingFigure3D) {
        /// Depth-aware stroke: slightly heavier and more opaque when nearer
        /// the camera, so the two views read as a body, not a wireframe.
        func stroke(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ color: Color, _ width: CGFloat) {
            let depth = (camera.depth(a) + camera.depth(b)) / 2
            let t = max(0, min(1, (depth + 0.5) / 1.0))
            var p = Path()
            p.move(to: camera.project(a))
            p.addLine(to: camera.project(b))
            ctx.stroke(p, with: .color(color.opacity(0.70 + 0.30 * t)),
                       style: StrokeStyle(lineWidth: width * (0.82 + 0.36 * t),
                                          lineCap: .round, lineJoin: .round))
        }
        func dot(_ at: SIMD3<Double>, _ diameter: CGFloat, _ color: Color) {
            let p = camera.project(at)
            let rect = CGRect(x: p.x - diameter / 2, y: p.y - diameter / 2,
                              width: diameter, height: diameter)
            ctx.fill(Circle().path(in: rect), with: .color(color))
        }

        // Pressure feet.
        for (foot, loaded) in [(figure.leadFoot, pose.weight), (figure.trailFoot, 1 - pose.weight)] {
            let p = camera.project(foot)
            let rect = CGRect(x: p.x - 15, y: p.y - 4, width: 30, height: 9)
            ctx.fill(Capsule().path(in: rect), with: .color(Theme.good.opacity(0.12 + 0.42 * loaded)))
        }

        let bone = Color.secondary
        stroke(figure.leadHip, figure.leadKnee, bone, 4.6)
        stroke(figure.leadKnee, figure.leadFoot, bone, 4.6)
        stroke(figure.trailHip, figure.trailKnee, bone, 4.6)
        stroke(figure.trailKnee, figure.trailFoot, bone, 4.6)
        stroke(figure.pelvis, figure.thorax, bone, 4.6)
        stroke(figure.thorax, figure.head, bone, 4.2)
        stroke(figure.leadShoulder, figure.hands, bone, 4.2)
        stroke(figure.trailShoulder, figure.hands, bone, 4.2)

        // Rotation bars — drawn through 3D, so face-on shows true
        // foreshortening as the body opens.
        stroke(figure.leadHip, figure.trailHip, hipTint, 6)
        stroke(figure.leadShoulder, figure.trailShoulder, shoulderTint, 6.5)

        // Club last, on top.
        stroke(figure.hands, figure.clubhead, .primary.opacity(0.72), 2.6)

        dot(figure.head, 17, .secondary.opacity(0.38))
        for joint in [figure.pelvis, figure.thorax, figure.leadKnee, figure.trailKnee] {
            dot(joint, 6.5, .secondary.opacity(0.55))
        }
        dot(figure.hands, 7.5, Theme.face.opacity(0.90))
        dot(figure.clubhead, 6.5, .primary.opacity(0.80))
    }

    // MARK: Club focus

    /// The Club subject: the shaft and head as delivered, plus a red ground
    /// arrow for club path + angle of attack and the arc's low point tagged
    /// relative to the ball. The speed-colored arc itself is already drawn by
    /// `drawTrail`. Honors both cameras — Face-On reads face angle and shaft
    /// lean, Down the Line reads path direction and loft.
    private func drawClubFocus(_ ctx: inout GraphicsContext, camera: StageCamera,
                               figure: SwingFigure3D, impact: ImpactDelivery,
                               lowPointPastBall: Double, trail: [SIMD3<Double>],
                               ball: SIMD3<Double>, showsAnnotations: Bool = true) {
        let clubhead = figure.clubhead
        let hands = figure.hands

        func stroke(_ path: Path, _ color: Color, _ width: CGFloat, dash: [CGFloat] = []) {
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
        }
        func seg(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Path {
            var p = Path(); p.move(to: camera.project(a)); p.addLine(to: camera.project(b)); return p
        }

        // Plumb line through the head — the gap to the shaft reads as forward lean.
        stroke(seg(clubhead - SIMD3<Double>(0, 0.05, 0), clubhead + SIMD3<Double>(0, 0.42, 0)),
               .secondary.opacity(0.40), 1, dash: [3, 4])

        // Shaft: hands lead the head toward the target.
        stroke(seg(hands, clubhead), .primary.opacity(0.80), 3)

        // Dark grip at the upper end of the metallic shaft.
        let gripEnd = hands + 0.18 * (clubhead - hands)
        stroke(seg(hands, gripEnd), .primary.opacity(0.96), 6)

        // Clubhead: leading edge, plus a tick for where the face points.
        let edge = 0.11 * ClubFocusGeometry.faceEdgeAxis(faceAngle: impact.faceAngle)
        stroke(seg(clubhead - edge, clubhead + edge), .primary.opacity(0.90), 5)
        let normal = 0.12 * ClubFocusGeometry.faceNormal(faceAngle: impact.faceAngle,
                                                         dynamicLoft: impact.dynamicLoft)
        stroke(seg(clubhead, clubhead + normal), Theme.face.opacity(0.90), 2)

        // Hands.
        let handsAt = camera.project(hands)
        ctx.fill(Circle().path(in: CGRect(x: handsAt.x - 4, y: handsAt.y - 4, width: 8, height: 8)),
                 with: .color(Theme.face.opacity(0.90)))

        guard showsAnnotations else { return }

        // Ground arrow from the ball: club-path heading tilted by angle of attack.
        let dir = ClubFocusGeometry.groundArrowVector(path: impact.clubPath, attack: impact.angleOfAttack)
        let baseAt = camera.project(ball)
        let tipAt = camera.project(ball + 0.60 * dir)
        var arrow = Path()
        arrow.move(to: baseAt); arrow.addLine(to: tipAt)
        let vx = tipAt.x - baseAt.x, vy = tipAt.y - baseAt.y
        let len = max(1, hypot(vx, vy))
        let ux = vx / len, uy = vy / len
        let wing: CGFloat = 8
        arrow.move(to: tipAt)
        arrow.addLine(to: CGPoint(x: tipAt.x - ux * wing - uy * wing * 0.6, y: tipAt.y - uy * wing + ux * wing * 0.6))
        arrow.move(to: tipAt)
        arrow.addLine(to: CGPoint(x: tipAt.x - ux * wing + uy * wing * 0.6, y: tipAt.y - uy * wing - ux * wing * 0.6))
        stroke(arrow, Theme.path.opacity(0.72), 1.7)
        let directionLabel: String
        switch viewAngle {
        case .top, .downTheLine:
            directionLabel = String(format: "Path %+.1f°", impact.clubPath)
        case .spatial, .faceOn:
            directionLabel = String(format: "AoA %+.1f°", impact.angleOfAttack)
        }
        ctx.draw(Text(directionLabel).font(.system(size: 8, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.path), at: CGPoint(x: tipAt.x, y: tipAt.y - 12))

        // Straight target-line reference (+x) from the ball.
        stroke(seg(ball, ball + 0.40 * SIMD3<Double>(1, 0, 0)), .secondary.opacity(0.30), 1, dash: [4, 4])

        // Arc low point, tagged relative to the ball.
        if let bottom = trail.min(by: { $0.y < $1.y }) {
            let past = lowPointPastBall >= 0
            let tint = past ? Theme.path : Theme.face
            let at = camera.project(bottom)
            ctx.stroke(Circle().path(in: CGRect(x: at.x - 6, y: at.y - 6, width: 12, height: 12)),
                       with: .color(tint), lineWidth: 1.5)
            let ballAt = camera.project(ball)
            let measureY = max(at.y, ballAt.y) + 12
            var measure = Path()
            measure.move(to: CGPoint(x: at.x, y: measureY))
            measure.addLine(to: CGPoint(x: ballAt.x, y: measureY))
            measure.move(to: CGPoint(x: at.x, y: measureY - 4))
            measure.addLine(to: CGPoint(x: at.x, y: measureY + 4))
            measure.move(to: CGPoint(x: ballAt.x, y: measureY - 4))
            measure.addLine(to: CGPoint(x: ballAt.x, y: measureY + 4))
            stroke(measure, tint.opacity(0.65), 1)
            let cm = abs(lowPointPastBall)
            let label = cm < 1 ? "low point at ball"
                : String(format: "low point %.0f cm %@", cm, past ? "ahead" : "behind")
            ctx.draw(Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(tint),
                     at: CGPoint(x: at.x, y: at.y - 13))
        }
        // The delivered face / loft / lean / attack / path numbers live in the
        // Face Delivery card on this same screen, so the stage stays uncluttered.
    }

    /// Fault coloring only makes sense at delivery: the simulated body is
    /// legitimately closed for most of the downswing.
    private var shoulderTint: Color {
        let faulted = pose.shoulder < -5 || pose.shoulder > 40
        let nearImpact = !pose.swinging || (0.70...0.80).contains(pose.progress)
        return faulted && nearImpact ? Theme.bad : Theme.path
    }

    private var hipTint: Color {
        let faulted = pose.hip < 20 || pose.hip > 55
        let nearImpact = !pose.swinging || (0.70...0.80).contains(pose.progress)
        return faulted && nearImpact ? Theme.bad : Theme.face
    }
}

#Preview("Face-On Impact") {
    let bio = Biomechanics()
    SwingStageView(pose: bio.engine.pose(at: 0.72), bio: bio, viewAngle: .faceOn)
        .frame(height: 380)
        .padding()
}

#Preview("Down the Line, OTT") {
    var bio = Biomechanics()
    let _ = BodyFault.library.first { $0.name == "Over the Top" }?.apply(to: &bio)
    SwingStageView(pose: bio.engine.pose(at: 0.65), bio: bio, viewAngle: .downTheLine)
        .frame(height: 380)
        .padding()
}

#Preview("Ghost Comparison") {
    var bio = Biomechanics()
    let _ = BodyFault.library.first { $0.name == "Cast & Scoop" }?.apply(to: &bio)
    SwingStageView(pose: bio.engine.pose(at: 0.68), bio: bio, viewAngle: .faceOn, showGhost: true)
        .frame(height: 380)
        .padding()
}

#Preview("Club Focus, Face-On") {
    let bio = Biomechanics()
    SwingStageView(pose: bio.engine.pose(at: 0.72), bio: bio, viewAngle: .faceOn, subject: .club)
        .frame(height: 380)
        .padding()
}

#Preview("Club Focus, Down the Line — Cast & Scoop") {
    var bio = Biomechanics()
    let _ = BodyFault.library.first { $0.name == "Cast & Scoop" }?.apply(to: &bio)
    SwingStageView(pose: bio.engine.pose(at: 0.72), bio: bio, viewAngle: .downTheLine, subject: .club)
        .frame(height: 380)
        .padding()
}
