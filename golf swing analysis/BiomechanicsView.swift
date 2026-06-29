//
//  BiomechanicsView.swift
//  golf swing analysis
//
//  The Body tab: interactive biomechanics with a top-down rotation diagram,
//  weight distribution, spine tilt, a kinematic-sequence chart, and a preview of
//  the club delivery the body produces — which can be sent to the Impact tab.
//

import SwiftUI

struct BiomechanicsView: View {
    @Bindable var lab: SwingLab
    @State private var faultLesson: String?
    @State private var showAdvanced = false
    @State private var progress: Double = 0.72   // 0 = address, 0.72 = impact, 1 = finish
    @State private var playing = false
    @State private var playStart = Date()

    private let swingDuration = 2.6

    private var bio: Biomechanics { lab.biomechanics }

    /// Figure progress: live time while playing, otherwise the scrubbed value.
    private func playProgress(now: Date) -> Double {
        guard playing else { return progress }
        let t = now.timeIntervalSince(playStart) / swingDuration
        if t >= 1 {
            DispatchQueue.main.async { if playing { playing = false; progress = 1 } }
            return 1
        }
        DispatchQueue.main.async { progress = t }   // keep the scrubber in sync
        return t
    }

    // MARK: - Phase label + callout

    private func swingPhase(_ pose: GolferPose) -> String {
        switch pose.progress {
        case ..<0.06: return "Address"
        case ..<0.50: return "Backswing"
        case ..<0.60: return "Top"
        case ..<0.72: return "Downswing"
        case ..<0.84: return "Impact"
        default: return "Follow-through"
        }
    }

    private func phaseCallout(_ pose: GolferPose) -> String {
        switch swingPhase(pose) {
        case "Address": return "Set up to the ball"
        case "Backswing": return "Turning back, hinging the wrists"
        case "Top": return "Top of backswing — fully coiled"
        case "Downswing":
            return bio.sequenceEfficiency >= 70 ? "Dropping into the slot, holding lag" : "Casting — releasing early"
        case "Impact":
            let weightWord = bio.weightShift >= 70 ? "weight forward" : "hanging back"
            let hipWord = bio.hipRotation >= 35 ? "hips open" : "hips stalled"
            return "\(weightWord), \(hipWord)"
        default: return "Releasing to a balanced finish"
        }
    }

    private func phaseBanner(_ pose: GolferPose) -> some View {
        VStack(spacing: 2) {
            Text(swingPhase(pose)).font(.caption.bold())
            Text(phaseCallout(pose)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    /// The shot the current body positions would produce.
    private var previewSwing: SwingModel {
        var s = SwingModel()
        lab.biomechanics.apply(to: &s)
        return s
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TimelineView(.animation(paused: !playing)) { tl in
                        let pose = GolferPose.swing(at: playProgress(now: tl.date), bio: bio)
                        GolferFigure(pose: pose)
                            .overlay(alignment: .top) { phaseBanner(pose) }
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            playStart = Date()
                            playing = true
                        } label: {
                            Label(playing ? "Playing…" : "Play", systemImage: "play.fill").font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(10)
                    }

                    // Scrubber — drag to stop the swing at any point and study it.
                    VStack(spacing: 2) {
                        Slider(value: $progress, in: 0...1) { editing in
                            if editing { playing = false }   // grabbing the slider pauses playback
                        }
                        HStack {
                            Text("Address"); Spacer(); Text("Top"); Spacer()
                            Text("Impact"); Spacer(); Text("Finish")
                        }
                        .font(.caption2).foregroundStyle(.tertiary)
                    }

                    HStack {
                        Text("Resulting shot").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(previewSwing.shotName).font(.headline)
                    }
                    .padding(.horizontal, 4)

                    faultPicker

                    VStack(spacing: 16) {
                        control("Shoulders", $lab.biomechanics.shoulderRotation, -20...50, low: "Closed", high: "Open", effect: bio.shoulderEffect)
                        control("Lead Wrist", $lab.biomechanics.leadWrist, -20...20, low: "Bowed", high: "Cupped", effect: bio.wristEffect)
                        control("Weight Shift", $lab.biomechanics.weightShift, 50...95, low: "Trail", high: "Lead", unit: "%", step: 1, effect: bio.weightEffect)
                    }

                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(spacing: 16) {
                            control("Hip Rotation", $lab.biomechanics.hipRotation, 0...70, low: "Closed", high: "Open", effect: bio.hipEffect)
                            control("Spine Tilt", $lab.biomechanics.spineTilt, 0...30, low: "Level", high: "Behind ball", effect: bio.spineEffect)
                            control("Kinematic Sequence", $lab.biomechanics.sequenceEfficiency, 0...100, low: "Out of sync", high: "Efficient", unit: "%", step: 1, effect: bio.sequenceEffect)
                            separationCard
                            KinematicSequenceView(segments: bio.sequence).frame(height: 150)
                        }
                        .padding(.top, 10)
                    } label: {
                        Label("Advanced", systemImage: "slider.horizontal.3").font(.headline)
                    }

                    Button { lab.sendBodyToImpact() } label: {
                        Label("Send to Impact", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset Body") {
                        lab.biomechanics = Biomechanics()
                        faultLesson = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Body")
        }
    }

    private var faultPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try a swing fault").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BodyFault.library) { fault in
                        Button {
                            withAnimation(.easeInOut(duration: 0.6)) { fault.apply(to: &lab.biomechanics) }
                            faultLesson = fault.lesson
                        } label: {
                            Text(fault.name)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.tint.opacity(0.15)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let faultLesson {
                Text(faultLesson).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func control(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                         low: String, high: String, unit: String = "°", step: Double = 0.5, effect: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ParameterSlider(title: title, value: value, range: range, unit: unit, lowLabel: low, highLabel: high, step: step)
            Text(effect).font(.caption2).italic().foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var separationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hip–Shoulder Separation").font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%+.0f°", bio.separation))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(qualityColor(bio.separationQuality))
            }
            SeparationBar(separation: bio.separation).frame(height: 14)
            Text(bio.separationNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func qualityColor(_ q: Biomechanics.Quality) -> Color {
        switch q {
        case .poor: return .red
        case .ok: return .orange
        case .good: return .green
        }
    }
}

// MARK: - Front-on golfer figure

/// A snapshot of the figure's drawable positions. Built either at impact (static)
/// or interpolated across a swing (animated).
struct GolferPose {
    var shoulder: Double
    var hip: Double
    var spine: Double
    var weight: Double       // 0…1 onto the lead foot
    var armAngle: Double     // hands' orbit around the chest (0 = down at the ball)
    var clubAngle: Double    // clubhead direction (0 = straight down at the ball)
    var wrist: Double
    /// true while mid-swing, so labels can hide.
    var swinging: Bool = false
    /// 0…1 progress through the swing (used for fault coloring near impact).
    var progress: Double = 1.0

    static func impact(_ bio: Biomechanics) -> GolferPose {
        GolferPose(shoulder: bio.shoulderRotation, hip: bio.hipRotation, spine: bio.spineTilt,
                   weight: (bio.weightShift - 50) / 45, armAngle: 0, clubAngle: 0, wrist: bio.leadWrist)
    }

    /// Interpolates address → top → impact → finish with realistic golf tempo
    /// (slow backswing, fast downswing, decelerating finish). The arms swing up
    /// and down (armAngle) while the club hinges off the hands (clubAngle = arm +
    /// wrist lag). Every phase is shaped by the slider values — e.g. a high
    /// Kinematic Sequence holds the lag, a low one casts it early.
    static func swing(at time: Double, bio: Biomechanics) -> GolferPose {
        let impactW = (bio.weightShift - 50) / 45
        let lag = bio.sequenceEfficiency / 100        // 0 = casts early, 1 = holds lag
        let tBack = 0.55                              // ~3:1 backswing-to-downswing tempo
        let tImpact = 0.72

        // Top-of-backswing positions now amplified so faults are clearly visible
        // throughout the swing, not just at impact.
        let topShoulder = -95 + bio.shoulderRotation * 0.6
        let topHip = -50 + bio.hipRotation * 0.5
        let topWeight = impactW < 0.12 ? 0.62 : 0.20      // only a true reverse pivot loads the lead side at the top

        var shoulder = 0.0, hip = 0.0, weight = 0.45, wrist = bio.leadWrist
        var arm = 0.0, hinge = 0.0                    // hands' arc and wrist cock

        if time < tBack {
            // Backswing — slow takeaway, arms swing up, wrists hinge.
            let p = smooth(time / tBack)
            shoulder = lerp(0, topShoulder, p)
            hip = lerp(0, topHip, p)
            weight = lerp(0.45, topWeight, p)
            wrist = lerp(bio.leadWrist, bio.leadWrist + 28, p)
            arm = lerp(0, 155, p)
            hinge = lerp(0, 70, p)
        } else if time < tImpact {
            // Downswing — fast; arms drop while the club holds its lag, then releases.
            let p = (time - tBack) / (tImpact - tBack)
            let pe = p * p
            shoulder = lerp(topShoulder, bio.shoulderRotation, pe)
            hip = lerp(topHip, bio.hipRotation, pe)
            weight = lerp(topWeight, impactW, pe)
            wrist = lerp(bio.leadWrist + 28, bio.leadWrist, pe)
            arm = lerp(155, 0, pe)
            hinge = 70 * (1 - pow(p, 0.6 + lag * 1.8))   // lag vs. cast
        } else {
            // Follow-through — arms swing up the lead side, club passes the hands.
            let q = (time - tImpact) / (1 - tImpact)
            let p = 1 - (1 - q) * (1 - q)
            shoulder = lerp(bio.shoulderRotation, bio.shoulderRotation + 95, p)
            hip = lerp(bio.hipRotation, bio.hipRotation + 70, p)
            weight = lerp(impactW, max(0.92, impactW), p)
            wrist = lerp(bio.leadWrist, bio.leadWrist - 45, p)
            arm = lerp(0, -150, p)
            hinge = lerp(0, -60, p)
        }

        return GolferPose(shoulder: shoulder, hip: hip, spine: bio.spineTilt,
                          weight: weight, armAngle: arm, clubAngle: arm + hinge,
                          wrist: wrist, swinging: true, progress: time)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }   // ease in-out
}

/// A 3D point in body space (x = right, y = up, z = toward the viewer / down-line).
private struct P3 { var x: Double; var y: Double; var z: Double }

/// Projects a body point through a fixed front-3/4 camera (azimuth + elevation),
/// so hips and shoulders rotating about the vertical axis read as real depth.
private func project(_ p: P3, az: Double, el: Double, scale: CGFloat, origin: CGPoint) -> CGPoint {
    let a = az * .pi / 180, e = el * .pi / 180
    let xc = p.x * cos(a) + p.z * sin(a)
    let zc = -p.x * sin(a) + p.z * cos(a)
    let yc = p.y * cos(e) - zc * sin(e)
    return CGPoint(x: origin.x + CGFloat(xc) * scale, y: origin.y - CGFloat(yc) * scale)
}

/// A pseudo-3D golfer viewed from a front-3/4 angle. Hips and shoulders are lines
/// that rotate about the vertical axis (so the turn shows as depth), the spine
/// side-bends, the lead leg loads with weight, and the club swings on its arc.
struct GolferFigure: View {
    
    // Stroke style helper
    private func lw(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    // Shift a point by x/y
    private func shift(_ point: CGPoint, _ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
        CGPoint(x: point.x + dx, y: point.y + dy)
    }

    // Ground shadow beneath the golfer
    private func groundEllipse(pr: (P3) -> CGPoint) -> some View {
        let center = pr(P3(x: 0, y: 0, z: 0))

        return Ellipse()
            .fill(.black.opacity(0.08))
            .frame(width: 130, height: 28)
            .position(center)
    }
    
    let pose: GolferPose

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scale = min(h * 0.40, w * 0.42)
            let origin = CGPoint(x: w * 0.5, y: h * 0.92)
            let pr: (P3) -> CGPoint = { project($0, az: 26, el: 14, scale: scale, origin: origin) }

            // Body dimensions (metres-ish), heights from the ground.
            let hipY = 0.95, shoulderY = 1.45
            let hipHalf = 0.18, shoulderHalf = 0.24, footHalf = 0.17

            let weightX = -(pose.weight - 0.5) * 0.34          // sway toward the lead side
            let sb = pose.spine * 1.4 * .pi / 180              // side bend
            let ht = pose.hip * .pi / 180                      // hip turn about vertical
            let st = pose.shoulder * .pi / 180                 // shoulder turn about vertical

            let pelvis = P3(x: weightX, y: hipY, z: 0)
            let spineLenY = shoulderY - hipY
            let neck = P3(x: pelvis.x + sin(sb) * spineLenY * 0.5, y: hipY + cos(sb) * spineLenY, z: 0)
            let head = P3(x: neck.x + sin(sb) * 0.16, y: neck.y + 0.17 * cos(sb), z: 0)

            // Hip and shoulder lines rotate about the vertical axis (the turn).
            let hipL = P3(x: pelvis.x - hipHalf * cos(ht), y: hipY, z: -hipHalf * sin(ht))
            let hipR = P3(x: pelvis.x + hipHalf * cos(ht), y: hipY, z: hipHalf * sin(ht))
            let shL = P3(x: neck.x - shoulderHalf * cos(st), y: neck.y, z: neck.z - shoulderHalf * sin(st))
            let shR = P3(x: neck.x + shoulderHalf * cos(st), y: neck.y, z: neck.z + shoulderHalf * sin(st))

            let footL = P3(x: -footHalf, y: 0, z: 0)
            let footR = P3(x: footHalf, y: 0, z: 0)

            // Arms swing up around the chest; the club hinges off the hands.
            let hub = P3(x: neck.x, y: neck.y - 0.08, z: 0.12)
            let armLen = 0.6, clubLen = 0.92
            let aRad = pose.armAngle * .pi / 180
            let hands = P3(x: hub.x + sin(aRad) * armLen, y: hub.y - cos(aRad) * armLen, z: hub.z + 0.08)
            let cRad = pose.clubAngle * .pi / 180
            let clubhead = P3(x: hands.x + sin(cRad) * clubLen, y: hands.y - cos(cRad) * clubLen, z: hands.z + 0.04)
            let ball = P3(x: -0.04, y: 0, z: 0.16)

            ZStack {
                groundEllipse(pr: pr)

                // Legs — the lead (left) leg darkens as weight loads it.
                bar(pr(hipL), pr(footL)).stroke(.primary.opacity(0.4 + 0.5 * pose.weight), style: lw(7))
                bar(pr(hipR), pr(footR)).stroke(.primary.opacity(0.9 - 0.45 * pose.weight), style: lw(7))

                // Torso mass — makes the figure read as a body, not loose lines.
                quad(pr(shL), pr(shR), pr(hipR), pr(hipL))
                    .fill(Color(.systemGray3).opacity(0.6))

                // Hips (turning) — fault-aware color.
                bar(pr(hipL), pr(hipR)).stroke(hipColor(pose), style: lw(8))
                // Spine.
                bar(pr(pelvis), pr(neck)).stroke(.primary, style: lw(6))
                // Shoulders (turning) — fault-aware color.
                bar(pr(shL), pr(shR)).stroke(shoulderColor(pose), style: lw(8))

                Circle().fill(.primary.opacity(0.85)).frame(width: scale * 0.17, height: scale * 0.17).position(pr(head))

                // Arms + club.
                bar(pr(shL), pr(hands)).stroke(.primary, style: lw(4))
                bar(pr(shR), pr(hands)).stroke(.primary, style: lw(4))
                bar(pr(hands), pr(clubhead)).stroke(.secondary, style: lw(3))
                Circle().fill(.gray).frame(width: 10, height: 10).position(pr(clubhead))
                Circle().fill(.white).stroke(.secondary).frame(width: 8, height: 8).position(pr(ball))

                // Joints — anchor the body parts so the figure reads clearly.
                Group {
                    jointDot(pr(shL), .blue); jointDot(pr(shR), .blue)
                    jointDot(pr(hipL), .orange); jointDot(pr(hipR), .orange)
                    jointDot(pr(hands), .purple)
                }

                // Lead-wrist / face indicator at the hands.
                RoundedRectangle(cornerRadius: 2).fill(.purple).frame(width: 18, height: 5)
                    .rotationEffect(.degrees(pose.wrist)).position(pr(hands))

                // Labels appear around impact (the rest position) to reduce clutter mid-swing.
                if abs(pose.progress - 0.72) < 0.06 {
                    figureLabel("Shoulders", at: shift(pr(shR), 0, -14), color: shoulderColor(pose))
                    figureLabel("Hips", at: shift(pr(hipR), 0, -12), color: hipColor(pose))
                    figureLabel("Wrist", at: shift(pr(hands), 32, 0), color: .purple)
                }
            }
        }
    }

    // MARK: - Fault-aware coloring

    /// Shoulder bar turns red when outside the ideal range (~0–35° open at impact).
    /// During the swing, fault coloring appears in the impact zone (progress 0.65–0.85)
    /// so the user sees the problem flash as the club comes through.
    private func shoulderColor(_ pose: GolferPose) -> Color {
        let faulted = pose.shoulder < -5 || pose.shoulder > 40
        if pose.swinging {
            let nearImpact = (0.65...0.85).contains(pose.progress)
            return (nearImpact && faulted) ? .red : .blue
        }
        return faulted ? .red : .blue
    }

    /// Hip bar turns red when outside the ideal range (~20–55° open at impact).
    private func hipColor(_ pose: GolferPose) -> Color {
        let faulted = pose.hip < 20 || pose.hip > 55
        if pose.swinging {
            let nearImpact = (0.65...0.85).contains(pose.progress)
            return (nearImpact && faulted) ? .red : .orange
        }
        return faulted ? .red : .orange
    }

    // MARK: - Drawing helpers

    private func bar(_ a: CGPoint, _ b: CGPoint) -> Path {
        Path { p in p.move(to: a); p.addLine(to: b) }
    }

    private func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Path {
        Path { p in p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.addLine(to: d); p.closeSubpath() }
    }

    private func jointDot(_ p: CGPoint, _ color: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8).position(p)
    }

    private func figureLabel(_ text: String, at p: CGPoint, color: Color) -> some View {
        Text(text).font(.system(size: 9, weight: .medium)).foregroundStyle(color).position(p)
    }
}

// MARK: - Separation range bar (ideal zone)

struct SeparationBar: View {
    let separation: Double
    private let minV = -10.0
    private let maxV = 60.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { v in
                CGFloat((min(max(v, minV), maxV) - minV) / (maxV - minV)) * w
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                // Ideal zone 20–45°.
                Capsule().fill(.green.opacity(0.4))
                    .frame(width: x(45) - x(20))
                    .offset(x: x(20))
                // Current value marker.
                Capsule().fill(.primary)
                    .frame(width: 3)
                    .offset(x: x(separation) - 1.5)
            }
        }
    }
}

// MARK: - Top-down rotation diagram

/// Looking down on the player: a vertical target line, with hip and shoulder
/// lines pivoting open/closed. Their separation is the key teaching cue.
struct RotationDiagram: View {
    let bio: Biomechanics

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let len = min(geo.size.width, geo.size.height) * 0.32

            ZStack {
                // Target line.
                Path { p in
                    p.move(to: CGPoint(x: c.x, y: 12))
                    p.addLine(to: CGPoint(x: c.x, y: geo.size.height - 12))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(.secondary)

                rotatedLine(center: c, length: len, openDegrees: bio.shoulderRotation, color: .blue, width: 6)
                rotatedLine(center: c, length: len * 0.8, openDegrees: bio.hipRotation, color: .orange, width: 6)

                Circle().fill(.primary).frame(width: 10, height: 10).position(c)

                VStack {
                    HStack(spacing: 16) {
                        legend(color: .blue, text: "Shoulders")
                        legend(color: .orange, text: "Hips")
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
    }

    /// Draws a body line rotated by `openDegrees` from the address position
    /// (perpendicular to the target line). Opening rotates the lead end (top).
    private func rotatedLine(center: CGPoint, length: CGFloat, openDegrees: Double, color: Color, width: CGFloat) -> some View {
        // At address the line is horizontal; opening rotates it toward the target.
        let angle = -openDegrees * .pi / 180
        let dx = cos(angle) * length
        let dy = sin(angle) * length
        return Path { p in
            p.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            p.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
        }
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2)
        }
    }
}

// MARK: - Kinematic sequence chart

/// A simple timeline showing when each segment peaks. Properly sequenced swings
/// stagger pelvis → torso → arm → club; poor ones bunch up.
struct KinematicSequenceView: View {
    let segments: [Biomechanics.Segment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kinematic Sequence").font(.headline)
            GeometryReader { geo in
                VStack(spacing: 6) {
                    ForEach(segments) { seg in
                        HStack(spacing: 8) {
                            Text(seg.name)
                                .font(.caption2)
                                .frame(width: 48, alignment: .leading)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Circle()
                                    .fill(color(for: seg.color))
                                    .frame(width: 14, height: 14)
                                    .offset(x: CGFloat(seg.peakTime) * (geo.size.width - 60))
                            }
                            .frame(height: 14)
                        }
                    }
                }
            }
        }
    }

    private func color(for c: Biomechanics.SegmentColor) -> Color {
        switch c {
        case .pelvis: return .orange
        case .torso: return .blue
        case .arm: return .green
        case .club: return .red
        }
    }
}
