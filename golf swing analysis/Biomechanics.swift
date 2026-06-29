//
//  Biomechanics.swift
//  golf swing analysis
//
//  The top of the cause-and-effect chain: the body. Holds the key biomechanical
//  positions at impact and maps them to the club-delivery conditions the
//  `SwingModel` engine consumes. Mappings are deliberately simplified and
//  directionally correct for teaching — they show *which way* a body change
//  pushes delivery, not exact tour data.
//
//  Right-handed convention. "Open" = rotated toward the target (lead side back).
//

import Foundation

struct Biomechanics {

    // MARK: Inputs (positions at impact)

    var hipRotation: Double = 40      // deg open to target — pelvis clearance
    var shoulderRotation: Double = 0  // deg open to target (thorax)
    var spineTilt: Double = 12        // deg of secondary tilt away from target
    var weightShift: Double = 75      // % of weight on the lead foot
    var leadWrist: Double = 0         // deg, cupped/extended(+) vs bowed/flexed(-)
    var sequenceEfficiency: Double = 80 // % quality of the kinematic sequence

    // MARK: Teaching-relevant derived values

    /// Hip-over-shoulder separation. Hips leading the shoulders (positive) is the
    /// hallmark of a good downswing sequence.
    var separation: Double { hipRotation - shoulderRotation }

    // MARK: Body → Club Delivery

    /// Club path. Open shoulders at impact throw the club out-to-in ("over the
    /// top"); cleared hips give room to swing in-to-out.
    var clubPath: Double {
        (hipRotation - 40) * 0.08 - shoulderRotation * 0.14
    }

    /// Face angle. A bowed (flexed) lead wrist closes the face; a cupped
    /// (extended) wrist opens it.
    var faceAngle: Double {
        leadWrist * 0.9
    }

    /// Forward shaft lean grows as weight moves onto the lead foot.
    var shaftLean: Double {
        (weightShift - 50) * 0.35
    }

    /// Angle of attack. Staying behind the ball (more tilt away) hits up; weight
    /// driving forward hits down.
    var angleOfAttack: Double {
        (spineTilt - 12) * 0.25 - (weightShift - 60) * 0.12
    }

    /// Delivered loft — de-lofted by forward lean, added to by a cupped wrist.
    var dynamicLoft: Double {
        16 - (shaftLean - 5) * 0.4 + leadWrist * 0.3
    }

    /// Clubhead speed. Hip clearance adds speed; a clean kinematic sequence keeps
    /// most of it.
    var swingSpeed: Double {
        let base = 96 + (hipRotation - 40) * 0.3
        return base * (0.75 + 0.25 * sequenceEfficiency / 100)
    }

    /// Applies the body-derived delivery onto a swing, leaving strike location and
    /// lie angle (which the body model doesn't drive) untouched.
    func apply(to swing: inout SwingModel) {
        swing.faceAngle = faceAngle
        swing.clubPath = clubPath
        swing.angleOfAttack = angleOfAttack
        swing.dynamicLoft = dynamicLoft
        swing.shaftLean = shaftLean
        swing.swingSpeed = swingSpeed
    }

    /// Labeled preview of the delivery this body position produces.
    var deliveryPreview: [(label: String, value: String)] {
        [
            ("Club Path", String(format: "%+.1f°", clubPath)),
            ("Club Face", String(format: "%+.1f°", faceAngle)),
            ("Angle of Attack", String(format: "%+.1f°", angleOfAttack)),
            ("Dynamic Loft", String(format: "%.1f°", dynamicLoft)),
            ("Shaft Lean", String(format: "%.1f°", shaftLean)),
            ("Swing Speed", String(format: "%.0f mph", swingSpeed))
        ]
    }
}

// MARK: - Live coaching: what each input is doing

extension Biomechanics {
    var hipEffect: String {
        if hipRotation >= 35 { return "Cleared \(Int(hipRotation))° — room to swing out and add speed." }
        if hipRotation < 25 { return "Stalled (\(Int(hipRotation))°) — crowds the arms, path goes left." }
        return "Turning, but clearing the hips more would help."
    }

    var shoulderEffect: String {
        if shoulderRotation > 12 { return "Open \(Int(shoulderRotation))° — throws the club out-to-in (over the top, slice path)." }
        if shoulderRotation < -5 { return "Closed \(Int(-shoulderRotation))° — swings in-to-out (draw/hook path)." }
        return "Near square — fairly neutral path."
    }

    var spineEffect: String {
        if spineTilt >= 18 { return "\(Int(spineTilt))° behind the ball — hitting up (great for driver)." }
        if spineTilt < 6 { return "Level — a steeper, downward strike." }
        return "Moderate tilt — a fairly neutral attack angle."
    }

    var weightEffect: String {
        if weightShift >= 78 { return "\(Int(weightShift))% forward — shaft lean and a ball-first strike." }
        if weightShift < 60 { return "Hanging back (\(Int(weightShift))%) — adds loft, fat/thin risk." }
        return "Decent shift — get a touch more onto the lead side."
    }

    var wristEffect: String {
        if leadWrist <= -3 { return "Bowed \(Int(-leadWrist))° — closes the face (lower, left)." }
        if leadWrist >= 3 { return "Cupped \(Int(leadWrist))° — opens the face (higher, right)." }
        return "Flat — a square face."
    }

    var sequenceEffect: String {
        if sequenceEfficiency >= 80 { return "\(Int(sequenceEfficiency))% — tour-like sequence, keeps speed." }
        if sequenceEfficiency < 55 { return "Out of sync (\(Int(sequenceEfficiency))%) — casts and leaks speed." }
        return "Decent sequence — tighten the order for more speed."
    }

    enum Quality { case poor, ok, good }

    /// Hip–shoulder separation quality. Hips well ahead of the shoulders is ideal.
    var separationQuality: Quality {
        let s = separation
        if s < 0 { return .poor }
        if s < 15 || s > 50 { return .ok }
        return .good
    }

    var separationNote: String {
        switch separationQuality {
        case .poor: return "Shoulders ahead of the hips — the sequence is backwards."
        case .ok: return separation > 50 ? "Very open hips — careful not to slide." : "Some separation — let the hips lead more."
        case .good: return "Strong separation — the hips are leading the downswing."
        }
    }
}

// MARK: - Common swing faults (tap to load)

struct BodyFault: Identifiable {
    let id = UUID()
    let name: String
    let hip, shoulder, spine, weight, wrist, sequence: Double
    let lesson: String
}

extension BodyFault {
    static let library: [BodyFault] = [
        BodyFault(name: "Over the Top", hip: 28, shoulder: 42, spine: 8, weight: 58, wrist: 0, sequence: 45,
                  lesson: "Shoulders spin open and the club comes down out-to-in across the ball — it starts left and slices right."),
        BodyFault(name: "Stalled Hips", hip: 16, shoulder: 6, spine: 12, weight: 66, wrist: -10, sequence: 48,
                  lesson: "The pelvis stops turning, so the hands flip past and the face shuts — a pull that hooks left."),
        BodyFault(name: "Flippy Release", hip: 38, shoulder: 2, spine: 16, weight: 56, wrist: 9, sequence: 55,
                  lesson: "Weight hangs back and the lead wrist scoops up through impact — the face flips open for a weak, high push-slice."),
        BodyFault(name: "Reverse Pivot", hip: 26, shoulder: 28, spine: 2, weight: 46, wrist: -2, sequence: 45,
                  lesson: "Weight leans toward the target at the top then falls back — a steep, weak strike that starts left and fades right."),
        BodyFault(name: "Tour Move", hip: 44, shoulder: -2, spine: 14, weight: 84, wrist: -1, sequence: 92,
                  lesson: "Hips lead, shoulders stay square, weight forward with a flat lead wrist — a square face just inside the path for a baby draw.")
    ]

    func apply(to bio: inout Biomechanics) {
        bio.hipRotation = hip
        bio.shoulderRotation = shoulder
        bio.spineTilt = spine
        bio.weightShift = weight
        bio.leadWrist = wrist
        bio.sequenceEfficiency = sequence
    }
}

// MARK: - Kinematic sequence

extension Biomechanics {
    /// One body segment in the kinematic sequence, in proper firing order.
    struct Segment: Identifiable {
        let id = UUID()
        let name: String
        /// Normalized time (0–1) where this segment reaches peak speed.
        let peakTime: Double
        let color: SegmentColor
    }

    enum SegmentColor { case pelvis, torso, arm, club }

    /// The four segments, staggered by sequence quality. High efficiency spreads
    /// the peaks out in the correct order (pelvis → torso → arm → club); low
    /// efficiency bunches them together (a poor, casting/over-the-top move).
    var sequence: [Segment] {
        let spread = sequenceEfficiency / 100        // 0 = bunched, 1 = well spread
        let ideal = [0.15, 0.38, 0.62, 0.85]         // proper proportional timing
        let bunched = [0.45, 0.50, 0.55, 0.60]       // everything firing at once
        let names = ["Pelvis", "Torso", "Arm", "Club"]
        let colors: [SegmentColor] = [.pelvis, .torso, .arm, .club]
        return (0..<4).map { i in
            let t = bunched[i] + (ideal[i] - bunched[i]) * spread
            return Segment(name: names[i], peakTime: t, color: colors[i])
        }
    }
}
