//
//  SwingModel.swift
//  golf swing analysis
//
//  The physics engine. Turns a full set of impact conditions (the things a
//  player or club delivers) into the resulting ball-flight outputs. The numbers
//  are simplified launch-monitor-style approximations chosen to be *directionally
//  correct and monotonic* for teaching — not a ballistics-grade simulation.
//
//  Right-handed convention, all angles in degrees relative to the target line:
//    positive = right / open / in-to-out, negative = left / closed / out-to-in.
//

import Foundation

/// All adjustable impact conditions, plus the computed ball-flight outputs.
struct SwingModel: Codable, Equatable {

    // MARK: Inputs

    var faceAngle: Double = 0        // deg, open(+)/closed(-)
    var clubPath: Double = 0         // deg, in-to-out(+)/out-to-in(-)
    var angleOfAttack: Double = 0    // deg, up(+)/down(-)
    var dynamicLoft: Double = 14     // deg, delivered loft at impact
    var swingSpeed: Double = 95      // mph, clubhead speed
    var strikeOffset: Double = 0     // mm off center face, toe(+)/heel(-)
    var strikeHeightOffset: Double = 0 // mm off center face, high(+)/low(-)
    var shaftLean: Double = 5        // deg, forward lean (de-lofts/lowers spin)
    var lieAngle: Double = 0         // deg, upright(+)/flat(-) at impact

    // MARK: Derived delivery values

    /// Face relative to path — the tilt of the spin axis comes from this.
    var faceToPath: Double { faceAngle - clubPath }

    /// Loft presented relative to the attack angle. Drives spin.
    var spinLoft: Double { max(0, dynamicLoft - angleOfAttack) }

    /// A `BallFlight` for the start/curve classification, naming, and coaching
    /// text already used elsewhere in the app.
    var ballFlight: BallFlight {
        BallFlight(faceAngle: faceAngle, clubPath: clubPath)
    }

    // MARK: Outputs

    static let faceInfluenceOnStart = 0.85

    /// Initial launch direction relative to target (deg). Mostly face, a little
    /// path, with a small lie-angle contribution (upright sends it left).
    var launchDirection: Double {
        SwingModel.faceInfluenceOnStart * faceAngle
            + (1 - SwingModel.faceInfluenceOnStart) * clubPath
            - 0.6 * lieAngle
    }

    /// Spin-axis tilt (deg). Positive curves right; negative curves left.
    /// Driven by face-to-path plus gear effect from an off-center strike.
    var spinAxis: Double {
        let raw = 0.9 * faceToPath - 0.15 * strikeOffset
        return min(45, max(-45, raw))
    }

    /// Vertical launch angle (deg).
    var launchAngle: Double {
        max(0, 0.8 * dynamicLoft + 0.3 * angleOfAttack)
    }

    /// Backspin (rpm). Grows with spin loft and speed; forward shaft lean
    /// de-lofts and lowers it.
    var backSpin: Double {
        max(500, spinLoft * swingSpeed * 1.9 - shaftLean * 60)
    }

    /// How efficiently energy transfers to the ball. Best with a center strike
    /// and low spin loft; punished by off-center hits and steep spin loft.
    var smashFactor: Double {
        var smash = 1.50
        smash -= 0.004 * abs(strikeOffset)
        smash -= 0.004 * abs(strikeHeightOffset)
        smash -= 0.006 * max(0, spinLoft - 12)
        return min(1.52, max(1.20, smash))
    }

    /// Ball speed off the face (mph).
    var ballSpeed: Double { swingSpeed * smashFactor }

    /// Estimated carry distance (yards). Uses ball speed scaled by how close the
    /// launch and spin are to an efficient window.
    var carryDistance: Double {
        let launchEff = exp(-pow((launchAngle - 14) / 12, 2))
        let spinEff = exp(-pow((backSpin - 2600) / 2500, 2))
        let base = ballSpeed * 1.6
        return base * (0.6 + 0.4 * launchEff) * (0.7 + 0.3 * spinEff)
    }

    /// Apex height (feet). Vertical component of ball speed, lofted by spin.
    var peakHeight: Double {
        let vy = ballSpeed * 1.467 * sin(launchAngle * .pi / 180) // ft/s
        let g = 32.2
        let spinLift = 1.0 + min(0.8, backSpin / 6000)
        return vy * vy / (2 * g) * spinLift
    }

    /// Rollout after landing (yards). Less for high, spinny shots.
    var rollout: Double {
        max(0, 30 - 0.8 * launchAngle - backSpin / 300)
    }

    /// Carry plus rollout (yards).
    var totalDistance: Double { carryDistance + rollout }

    // MARK: Classification (gear-effect aware)

    /// Observable start, curve, and finish properties, classified in one place.
    var flightClassification: BallFlight.Classification {
        return BallFlight.classify(
            startAngle: launchDirection,
            curveAmount: spinAxis,
            finishAmount: landingOffline
        )
    }

    /// Shot shape name based on launch direction and spin-axis tilt, so an
    /// off-center strike's gear effect is reflected (unlike a pure face/path
    /// classification).
    var shotName: String {
        flightClassification.shotName
    }
}

// MARK: - Output metrics for display

extension SwingModel {
    /// A labeled, formatted output value for the live data readout.
    struct Metric: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    var metrics: [Metric] {
        [
            Metric(label: "Shot Shape", value: shotName),
            Metric(label: "Launch Dir", value: String(format: "%+.1f°", launchDirection)),
            Metric(label: "Spin Axis", value: String(format: "%+.1f°", spinAxis)),
            Metric(label: "Carry", value: String(format: "%.0f yd", carryDistance)),
            Metric(label: "Launch Angle", value: String(format: "%.1f°", launchAngle)),
            Metric(label: "Peak Height", value: String(format: "%.0f ft", peakHeight)),
            Metric(label: "Rollout", value: String(format: "%.0f yd", rollout)),
            Metric(label: "Smash", value: String(format: "%.2f", smashFactor))
        ]
    }
}
