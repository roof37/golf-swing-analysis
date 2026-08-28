//
//  SwingStage.swift
//  golf swing analysis
//
//  The motion-analysis stage. The figure lives in real 3D world space
//  (meters; +x toward the target, +y up, +z out toward the ball line) and is
//  rendered through one of two orthographic cameras:
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

enum StageViewAngle: String, CaseIterable, Identifiable {
    case faceOn = "Face-On"
    case downTheLine = "Down the Line"
    var id: String { rawValue }
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
        case .faceOn: return CGPoint(x: -p.x, y: p.y)
        case .downTheLine: return CGPoint(x: p.z, y: p.y)
        }
    }

    /// Depth toward the camera (bigger = nearer), for subtle weight cues.
    static func depth(_ p: SIMD3<Double>, angle: StageViewAngle) -> Double {
        switch angle {
        case .faceOn: return p.z
        case .downTheLine: return -p.x
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
    var showGhost: Bool = false

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
            var fitPoints = trailPoints
            fitPoints.append(contentsOf: [figure.leadFoot, figure.trailFoot, figure.head, ball])
            if let ghost { fitPoints.append(contentsOf: ghost.trail) }
            let camera = StageCamera(fitting: fitPoints, angle: viewAngle, size: size)

            drawBackdrop(&ctx, camera: camera, size: size, plane: plane, ball: ball)
            if let ghost {
                drawGhost(&ctx, camera: camera, ghost: (ghost.bio, ghost.trail),
                          progress: pose.progress, club: club)
            }
            // With a ghost on stage, heat is normalized to the faster swing —
            // a leaky sequence visibly never reaches full temperature.
            let normSpeed = max(output.headSpeeds.max() ?? 1, ghost?.maxSpeed ?? 1)
            drawTrail(&ctx, camera: camera, points: trailPoints,
                      speeds: output.headSpeeds, normalizeTo: normSpeed, ball: ball)
            drawFigure(&ctx, camera: camera, figure: figure)
        }
        .background(Color(.systemBackground).opacity(0.50), in: RoundedRectangle(cornerRadius: Theme.insetRadius))
        .accessibilityLabel("Motion analysis: \(viewAngle.rawValue) view of the swing with a speed-colored clubhead trail")
    }

    // MARK: Backdrop

    private func drawBackdrop(_ ctx: inout GraphicsContext, camera: StageCamera,
                              size: CGSize, plane: SwingPlane, ball: SIMD3<Double>) {
        let groundY = camera.project(SIMD3(0, 0, 0)).y

        var ground = Path()
        ground.move(to: CGPoint(x: 10, y: groundY))
        ground.addLine(to: CGPoint(x: size.width - 10, y: groundY))
        ctx.stroke(ground, with: .color(.secondary.opacity(0.22)), lineWidth: 1.25)

        let ballPoint = camera.project(ball)

        switch viewAngle {
        case .faceOn:
            // Stance center reference.
            var center = Path()
            center.move(to: CGPoint(x: camera.project(SIMD3(0, 2.1, 0)).x, y: size.height * 0.08))
            center.addLine(to: CGPoint(x: camera.project(SIMD3(0, 0, 0)).x, y: groundY))
            ctx.stroke(center, with: .color(.secondary.opacity(0.10)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            // Target direction along the ground.
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
            ctx.draw(Text("TARGET ⊙").font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.65)),
                     at: CGPoint(x: ballPoint.x, y: groundY + 10))
        }
    }

    // MARK: Ghost overlay

    private func drawGhost(_ ctx: inout GraphicsContext, camera: StageCamera,
                           ghost: (bio: Biomechanics, trail: [SIMD3<Double>]), progress: Double,
                           club: Biomechanics.Club) {
        var arc = Path()
        for (i, p) in ghost.trail.enumerated() {
            let point = camera.project(p)
            if i == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
        }
        ctx.stroke(arc, with: .color(.secondary.opacity(0.16)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Ghost arm + club at the same moment of the swing.
        let gMech = ghost.bio.mechanics
        let gPose = gMech.timeline.pose(at: progress)
        let gFigure = SwingFigure3D(pose: gPose, club: club, plane: gMech.plane)
        var limbs = Path()
        limbs.move(to: camera.project(gFigure.thorax))
        limbs.addLine(to: camera.project(gFigure.hands))
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
                           normalizeTo maxSpeed: Double, ball: SIMD3<Double>) {
        guard points.count > 2 else { return }
        let screen = points.map(camera.project)

        // The whole arc, faintly — the road ahead.
        var whole = Path()
        whole.move(to: screen[0])
        for p in screen.dropFirst() { whole.addLine(to: p) }
        ctx.stroke(whole, with: .color(.secondary.opacity(0.10)), lineWidth: 1)

        // The traveled part, colored by clubhead speed. The gradient is the
        // teaching visual: a good sequence stays cool most of the way down
        // and ignites at the bottom; a cast warms early and never gets hot.
        let norm = max(maxSpeed, 1)
        let lastIndex = max(1, min(screen.count - 1, Int(pose.progress * Double(screen.count - 1))))
        for i in 1...lastIndex {
            let f = speeds[i] / norm
            var seg = Path()
            seg.move(to: screen[i - 1])
            seg.addLine(to: screen[i])
            ctx.stroke(seg, with: .color(trailColor(fraction: f).opacity(0.20 + 0.65 * f)),
                       style: StrokeStyle(lineWidth: 1.0 + 2.4 * f, lineCap: .round))
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
