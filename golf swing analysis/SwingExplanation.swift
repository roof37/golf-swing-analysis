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

        // Path: over-the-top (thorax outracing the sequence) vs pelvis clearance.
        if bio.overTheTop > 3 {
            lines.append("The thorax is \(deg(bio.thoraxRotation)) open but the sequence only earned \(Int(bio.earnedThorax))° — the extra came early, throwing the club out-to-in → path \(deg(bio.clubPath)).")
        } else if bio.pelvisRotation >= 38 {
            lines.append("A cleared pelvis (\(deg(bio.pelvisRotation)) open) with the sequence delivering the thorax on time swings the club from the inside → path \(deg(bio.clubPath)).")
        } else {
            lines.append("A stalled pelvis (\(deg(bio.pelvisRotation)) open) crowds the arms and drags the club across the ball → path \(deg(bio.clubPath)).")
        }

        // Face from lead wrist.
        let w = bio.leadWrist
        let wristWord = w < -1 ? "bowed (flexed)" : w > 1 ? "cupped (extended)" : "flat"
        let faceWord = w < -1 ? "closes" : w > 1 ? "opens" : "squares"
        lines.append("A \(wristWord) lead wrist \(faceWord) the face → \(deg(bio.faceAngle)).")

        // Low point: one location drives attack, lean, and loft together.
        let lp = bio.lowPointPastBall
        let lpWord = lp > 1 ? "past the ball — a descending, ball-first strike"
            : lp < -1 ? "before the ball — catching it on the upswing"
            : "right at the ball"
        lines.append("\(Int(bio.leadPressure))% lead pressure and \(deg(bio.sideBend)) of side bend bottom the arc \(lpWord) → attack \(deg(bio.angleOfAttack)), lean \(deg(bio.shaftLean)), loft \(String(format: "%.1f°", bio.dynamicLoft)).")

        // Speed: coil × sequence — multiplicative, not additive.
        if bio.transitionSequence >= 70 {
            lines.append("\(Int(bio.separation))° of separation cashed in through a \(Int(bio.transitionSequence))% sequence → \(Int(bio.swingSpeed)) mph.")
        } else {
            lines.append("A \(Int(bio.transitionSequence))% sequence casts the coil away — \(Int(bio.separation))° of separation only delivers \(Int(bio.swingSpeed)) mph.")
        }

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

    private var startWord: String {
        if swing.launchDirection > BallFlight.startDeadband { return "right of target" }
        if swing.launchDirection < -BallFlight.startDeadband { return "left of target" }
        return "on target"
    }

    private var curveWord: String {
        switch swing.flightClassification.curveDirection {
        case .right: return "curve right"
        case .left: return "curve left"
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
