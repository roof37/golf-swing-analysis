//
//  SwingExplanation.swift
//  golf swing analysis
//
//  Generates the plain-language cause-and-effect narrative for Learning Mode:
//  how the body produces the delivery, how the delivery sets up impact, and how
//  impact creates the ball flight. Each link reports the dominant cause so a
//  player learns *why*, not just *what*.
//

import Foundation

struct SwingExplanation {
    let swing: SwingModel
    let bio: Biomechanics

    // MARK: Body → Club Delivery

    var bodyToDelivery: [String] {
        var lines: [String] = []

        // Path: compare the shoulder and hip contributions, name the dominant one.
        let shoulderEffect = -bio.shoulderRotation * 0.14   // open shoulders → out-to-in
        let hipEffect = (bio.hipRotation - 40) * 0.08       // cleared hips → in-to-out
        if abs(shoulderEffect) >= abs(hipEffect) {
            let sh = bio.shoulderRotation
            lines.append("Shoulders \(open(sh)) at impact throw the club \(sh > 0 ? "out-to-in (over the top)" : "in-to-out") → path \(deg(bio.clubPath)).")
        } else {
            lines.append("Cleared hips (\(deg(bio.hipRotation)) open) give room to swing in-to-out → path \(deg(bio.clubPath)).")
        }

        // Face from lead wrist.
        let w = bio.leadWrist
        let wristWord = w < -1 ? "bowed (flexed)" : w > 1 ? "cupped (extended)" : "flat"
        let faceWord = w < -1 ? "closes" : w > 1 ? "opens" : "squares"
        lines.append("A \(wristWord) lead wrist \(faceWord) the face → \(deg(bio.faceAngle)).")

        // Angle of attack from weight + spine tilt.
        lines.append("Weight \(Int(bio.weightShift))% on the lead foot with \(deg(bio.spineTilt)) of tilt → attack \(deg(bio.angleOfAttack)).")

        // Speed.
        lines.append("Hip speed and a \(Int(bio.sequenceEfficiency))% kinematic sequence deliver \(Int(bio.swingSpeed)) mph.")

        return lines
    }

    // MARK: Club Delivery → Impact

    var deliveryToImpact: [String] {
        var lines: [String] = []
        lines.append("Face is \(deg(swing.faceToPath)) relative to the path — the single number that tilts the spin axis.")
        lines.append("Spin loft (loft − attack) is \(deg(swing.spinLoft)), producing \(Int(swing.backSpin)) rpm of backspin.")

        let s = swing.strikeOffset
        if abs(s) < 3 {
            lines.append("A centered strike keeps smash high at \(String(format: "%.2f", swing.smashFactor)).")
        } else {
            let gear = s > 0 ? "draw spin (toe gear effect)" : "fade spin (heel gear effect)"
            lines.append("A \(Int(abs(s))) mm \(s > 0 ? "toe" : "heel") strike adds \(gear) and drops smash to \(String(format: "%.2f", swing.smashFactor)).")
        }
        lines.append("Ball speed = \(Int(swing.ballSpeed)) mph off the face.")
        return lines
    }

    // MARK: Impact → Ball Flight

    var impactToFlight: [String] {
        var lines: [String] = []
        lines.append("The face controls ~85% of start direction → the ball launches \(startWord) (\(deg(swing.launchDirection))).")
        lines.append("Spin-axis tilt of \(deg(swing.spinAxis)) makes it \(curveWord).")
        lines.append("Result: a \(swing.shotName) carrying \(Int(swing.carryDistance)) yd to a \(Int(swing.peakHeight)) ft apex, then \(Int(swing.rollout)) yd of rollout.")
        return lines
    }

    // MARK: Helpers

    private func deg(_ v: Double) -> String { String(format: "%+.1f°", v) }

    private func open(_ v: Double) -> String {
        if v > 1 { return "\(deg(v)) open" }
        if v < -1 { return "\(deg(v)) closed" }
        return "square"
    }

    private var startWord: String {
        if swing.launchDirection > BallFlight.startDeadband { return "right of target" }
        if swing.launchDirection < -BallFlight.startDeadband { return "left of target" }
        return "on target"
    }

    private var curveWord: String {
        switch swing.ballFlight.curve {
        case .slice: return "slice hard right"
        case .fade: return "fade gently right"
        case .draw: return "draw gently left"
        case .hook: return "hook hard left"
        case .straight: return "hold a straight line"
        }
    }
}

// MARK: - Are the body and the delivery currently linked?

extension SwingLab {
    /// True when the simulator's delivery matches what the body would produce —
    /// i.e. the cause-and-effect chain is fully consistent end to end.
    var deliveryMatchesBody: Bool {
        abs(swing.clubPath - biomechanics.clubPath) < 0.3
            && abs(swing.faceAngle - biomechanics.faceAngle) < 0.3
            && abs(swing.angleOfAttack - biomechanics.angleOfAttack) < 0.3
            && abs(swing.dynamicLoft - biomechanics.dynamicLoft) < 0.5
            && abs(swing.swingSpeed - biomechanics.swingSpeed) < 1.0
    }
}
