//
//  Biomechanics.swift
//  golf swing analysis
//
//  The top of the cause-and-effect chain: the body. Uses the vocabulary of
//  3D motion capture (pelvis / thorax / lead pressure / side bend) and maps the
//  body's impact positions to the club-delivery conditions the `SwingModel`
//  engine consumes.
//
//  Unlike a lookup table, the mappings are *coupled*, the way real biomechanics
//  couple:
//    • Speed is multiplicative — coil and ground pressure only pay off through
//      a clean transition sequence. A big turn with a poor sequence LOSES speed.
//    • Over-the-top is emergent — the sequence "earns" how open the thorax may
//      be at impact; a thorax that outraces its sequence throws the path left.
//    • One low-point location drives attack angle, shaft lean, and dynamic
//      loft together, instead of three unrelated formulas.
//
//  Constants are tuned so the Tour Move preset lands on launch-monitor-plausible
//  numbers for both clubs. Right-handed convention. "Open" = rotated toward the
//  target (lead side back).
//

import Foundation

struct Biomechanics: Equatable {

    // MARK: Club context

    /// The club being delivered. The same body produces very different delivery
    /// numbers with a driver (ball forward, hit up, little lean) than a 7-iron
    /// (ball centered, hit down, forward lean).
    enum Club: String, CaseIterable, Identifiable {
        case driver = "Driver"
        case iron = "7-Iron"

        var id: String { rawValue }

        /// Clubhead speed a neutral body would produce (mph, before the
        /// sequence/coil/pressure gains).
        var baseSpeed: Double {
            switch self {
            case .driver: return 107
            case .iron: return 87
            }
        }

        /// Loft built into the club (deg); lean and wrist modify it at impact.
        var staticLoft: Double {
            switch self {
            case .driver: return 14
            case .iron: return 34
            }
        }

        /// How far the ball sits ahead of stance center (cm). Forward ball
        /// position is why the driver is struck on the upswing.
        var ballForward: Double {
            switch self {
            case .driver: return 16
            case .iron: return 0
            }
        }

        /// Setup bias on forward shaft lean (deg): irons are soled with lean,
        /// the driver is teed with the shaft near vertical.
        var leanBias: Double {
            switch self {
            case .driver: return -3
            case .iron: return 4
            }
        }
    }

    // MARK: Inputs (capture-style positions at impact)

    var club: Club = .driver
    var pelvisRotation: Double = 42     // deg open to target — pelvis clearance
    var thoraxRotation: Double = 20     // deg open to target (rib cage)
    var leadPressure: Double = 82       // % of pressure on the lead foot
    var sideBend: Double = 14           // deg of secondary tilt away from target
    var leadWrist: Double = 0           // deg, cupped/extended(+) vs bowed/flexed(-)
    var transitionSequence: Double = 85 // % quality of the transition (pelvis→torso→arm→club)

    // MARK: Intermediate biomechanical state

    /// Pelvis-over-thorax separation ("X-factor" at impact). The pelvis leading
    /// the rib cage is the hallmark of a good downswing.
    var separation: Double { mechanics.diagnostics.separation }

    /// Complete mechanics output for this body position.
    var mechanics: SwingMechanicsOutput { SwingMechanicsEngine.output(for: self) }

    /// How open (deg) the thorax is *allowed* to be at impact for this sequence
    /// quality. A clean sequence lets the rib cage fire late and hard; a poor
    /// one means the same openness arrived early — over the top.
    var earnedThorax: Double { mechanics.diagnostics.earnedThorax }

    /// Degrees of thorax rotation that outran the sequence. This — not open
    /// shoulders per se — is what throws the club out-to-in.
    var overTheTop: Double { mechanics.diagnostics.overTheTop }

    /// Where the swing arc bottoms out, in cm ahead (+, toward the target) of
    /// stance center. Lead pressure moves it forward (only as fast as the
    /// sequence delivers it); side bend behind the ball pulls it back.
    var lowPointAhead: Double { mechanics.diagnostics.lowPointAhead }

    /// Arc bottom relative to the ball (cm, + = bottoms past the ball →
    /// descending strike). The club's ball position sets the sign convention:
    /// the same body low point is "down" on an iron and "up" on a driver.
    var lowPointPastBall: Double { mechanics.diagnostics.lowPointPastBall }

    // MARK: Body → Club Delivery

    /// Club path. Cleared pelvis earns room to swing in-to-out (delivered
    /// through the sequence); a thorax that outraces the sequence yanks it
    /// out-to-in; a genuinely closed thorax pushes in-to-out.
    var clubPath: Double { mechanics.impact.clubPath }

    /// Face angle — owned by the lead wrist (bowed closes, cupped opens), with
    /// a small opening flip when a poor sequence hangs back and scoops.
    var faceAngle: Double { mechanics.impact.faceAngle }

    /// The cached swing timeline for this body.
    var engine: SwingEngine.Output { mechanics.timeline }

    /// Angle of attack, measured from the simulated clubhead's velocity vector
    /// where it meets the ball. The same low point that drives lean and loft
    /// positions the ball against the simulated arc.
    var angleOfAttack: Double { mechanics.impact.angleOfAttack }

    /// Forward shaft lean: hands lead by however far the arc bottoms forward,
    /// plus the club's setup bias; a bowed wrist adds a touch more.
    var shaftLean: Double { mechanics.impact.shaftLean }

    /// Delivered loft — the club's static loft, de-lofted by forward lean,
    /// added to by a cupped wrist.
    var dynamicLoft: Double { mechanics.impact.dynamicLoft }

    /// Clubhead speed at the ball, measured from the simulation. The gating is
    /// emergent: coil and pressure raise the drive torque, but a poor sequence
    /// releases the wrist latch early, and an early-released club has already
    /// peaked and slowed by the time it reaches the ball.
    var swingSpeed: Double { mechanics.impact.swingSpeed }
    /// Applies the body-derived delivery onto a swing, leaving strike location
    /// and lie angle (which the body model doesn't drive) untouched.
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
    var pelvisEffect: String {
        if pelvisRotation >= 38 { return "Cleared \(Int(pelvisRotation))° — room to swing out, coil to cash in." }
        if pelvisRotation < 25 { return "Stalled (\(Int(pelvisRotation))°) — crowds the arms and drags the path left." }
        return "Turning, but clearing the pelvis more would open up the path."
    }

    /// Sequence-aware: the same open thorax is fine when the sequence earned it
    /// and over-the-top when it didn't.
    var thoraxEffect: String {
        if overTheTop > 3 {
            return "Open \(Int(thoraxRotation))° but the sequence only earned \(Int(earnedThorax))° — over the top, path left."
        }
        if thoraxRotation < -5 { return "Closed \(Int(-thoraxRotation))° — holds the path in-to-out (draw side)." }
        if thoraxRotation > 30 { return "Very open, but the sequence is delivering it — speed without the pull." }
        return "Square-ish rib cage — the path is set by the pelvis and sequence."
    }

    var pressureEffect: String {
        if leadPressure >= 78 { return "\(Int(leadPressure))% lead — the low point moves forward for a ball-first strike." }
        if leadPressure < 62 { return "Hanging back (\(Int(leadPressure))%) — the arc bottoms early: loft, flips, fat/thin." }
        return "Decent shift — a touch more lead pressure sharpens the strike."
    }

    var sideBendEffect: String {
        if sideBend >= 18 { return "\(Int(sideBend))° behind the ball — pulls the low point back to hit up (driver's friend)." }
        if sideBend < 6 { return "Level — the low point creeps forward for a steeper hit." }
        return "Moderate side bend — a fairly neutral low point."
    }

    var wristEffect: String {
        if leadWrist <= -3 { return "Bowed \(Int(-leadWrist))° — closes and de-lofts the face (lower, left)." }
        if leadWrist >= 3 { return "Cupped \(Int(leadWrist))° — opens and adds loft (higher, right)." }
        return "Flat — a square face."
    }

    var sequenceEffect: String {
        if transitionSequence >= 80 { return "\(Int(transitionSequence))% — pelvis→torso→arm→club in order; the coil reaches the ball." }
        if transitionSequence < 55 { return "Out of sync (\(Int(transitionSequence))%) — casting throws the coil away and un-earns the thorax turn." }
        return "Decent sequence — tightening the order converts more coil to speed."
    }

    enum Quality { case poor, ok, good }

    /// Pelvis–thorax separation quality at impact. ~15–35° is the strong window.
    var separationQuality: Quality {
        let s = separation
        if s < 5 { return .poor }
        if s < 15 || s > 40 { return .ok }
        return .good
    }

    var separationNote: String {
        switch separationQuality {
        case .poor: return "Rib cage has caught the pelvis — the sequence is running backwards."
        case .ok: return separation > 40 ? "Huge separation — strong, but watch for a stuck club." : "Some separation — let the pelvis lead more."
        case .good: return "Strong separation — the pelvis is leading and the coil is loaded."
        }
    }
}

// MARK: - Common swing patterns (tap to load)

struct BodyFault: Identifiable {
    let id = UUID()
    let name: String
    let pelvis, thorax, side, pressure, wrist, sequence: Double
    let lesson: String
}

extension BodyFault {
    static let library: [BodyFault] = [
        BodyFault(name: "Over the Top", pelvis: 30, thorax: 40, side: 8, pressure: 62, wrist: -2, sequence: 40,
                  lesson: "The rib cage fires first and outruns the sequence — the club comes down out-to-in and the coil never reaches the ball. Starts left, slices right, and leaks speed."),
        BodyFault(name: "Stalled Pivot", pelvis: 16, thorax: 5, side: 12, pressure: 68, wrist: -10, sequence: 50,
                  lesson: "The pelvis stops turning, so the hands flip past and the bowed wrist slams the face shut — a pull that hooks left."),
        BodyFault(name: "Cast & Scoop", pelvis: 38, thorax: 18, side: 16, pressure: 55, wrist: 9, sequence: 45,
                  lesson: "Pressure hangs back and the wrists release early — the arc bottoms behind the ball, the face flips open and adds loft. Weak, high, and to the right."),
        BodyFault(name: "Reverse Pivot", pelvis: 25, thorax: 30, side: 2, pressure: 50, wrist: -2, sequence: 45,
                  lesson: "Weight leans toward the target going back, then falls away coming down — no coil to spend and a weak, floaty strike that starts left and fades."),
        BodyFault(name: "Tour Move", pelvis: 45, thorax: 22, side: 14, pressure: 85, wrist: -1, sequence: 92,
                  lesson: "Pelvis leads, the sequence earns the open rib cage, pressure is forward with a flat lead wrist — a square face just inside the path for a strong baby draw.")
    ]

    func apply(to bio: inout Biomechanics) {
        bio.pelvisRotation = pelvis
        bio.thoraxRotation = thorax
        bio.sideBend = side
        bio.leadPressure = pressure
        bio.leadWrist = wrist
        bio.transitionSequence = sequence
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

    /// The four segments' peak-speed times, measured from the simulation. A
    /// clean sequence staggers pelvis → torso → arm → club with the club
    /// peaking at the ball; a cast releases early, so the club's peak slides
    /// forward and bunches into the arm's — the signature of a poor sequence.
    var sequence: [Segment] {
        let peaks = mechanics.diagnostics.peakTimes
        let names = ["Pelvis", "Torso", "Arm", "Club"]
        let colors: [SegmentColor] = [.pelvis, .torso, .arm, .club]
        return (0..<4).map { i in
            Segment(name: names[i], peakTime: peaks[i], color: colors[i])
        }
    }
}
