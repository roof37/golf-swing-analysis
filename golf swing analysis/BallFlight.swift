//
//  BallFlight.swift
//  golf swing analysis
//
//  Models the simplified "ball flight laws": how club face angle and club path
//  at impact combine to produce the ball's start direction and curvature.
//
//  Conventions (right-handed golfer, all angles in degrees relative to the
//  target line, looking down the target line):
//    - Positive  = pointing/aimed to the RIGHT of target.
//    - Negative  = pointing/aimed to the LEFT of target.
//

import Foundation

/// A simplified, research-oriented model of impact conditions and the resulting
/// shot shape. Distances are illustrative rather than ballistically exact, so the
/// relationships stay easy to reason about for teaching.
struct BallFlight {

    /// Club face angle relative to the target line at impact, in degrees.
    /// Positive = open (aimed right), negative = closed (aimed left).
    var faceAngle: Double

    /// Club path relative to the target line at impact, in degrees.
    /// Positive = in-to-out (swinging right), negative = out-to-in (swinging left).
    var clubPath: Double

    /// Fraction of the start direction attributed to the face (vs. the path).
    /// Modern launch-monitor data puts this around 0.85 for irons.
    static let faceInfluenceOnStart = 0.85

    /// The ball's initial launch direction relative to target, in degrees.
    /// Dominated by the face, nudged by the path.
    var startDirection: Double {
        BallFlight.faceInfluenceOnStart * faceAngle
            + (1 - BallFlight.faceInfluenceOnStart) * clubPath
    }

    /// Face-to-path: the difference that tilts the spin axis and curves the ball.
    /// Positive = face open to the path → curves right (fade/slice).
    /// Negative = face closed to the path → curves left (draw/hook).
    var faceToPath: Double {
        faceAngle - clubPath
    }
}

// MARK: - Classification

extension BallFlight {

    /// Where the ball starts relative to target.
    enum StartSide: String {
        case left = "Pull"
        case straight = "Straight"
        case right = "Push"
    }

    /// How the ball curves in the air.
    enum Curve {
        case draw      // gentle right-to-left (RH)
        case hook      // strong right-to-left
        case straight
        case fade      // gentle left-to-right (RH)
        case slice     // strong left-to-right

        var label: String {
            switch self {
            case .draw: return "Draw"
            case .hook: return "Hook"
            case .straight: return "Straight"
            case .fade: return "Fade"
            case .slice: return "Slice"
            }
        }
    }

    /// Degrees of start direction within which we call the start "straight".
    static let startDeadband = 1.0
    /// Degrees of face-to-path within which we call the flight "straight".
    static let curveDeadband = 1.0
    /// Face-to-path magnitude beyond which a curve becomes a hook/slice.
    static let severeCurveThreshold = 5.0

    var startSide: StartSide {
        if startDirection > BallFlight.startDeadband { return .right }
        if startDirection < -BallFlight.startDeadband { return .left }
        return .straight
    }

    var curve: Curve {
        let f = faceToPath
        if f > BallFlight.severeCurveThreshold { return .slice }
        if f > BallFlight.curveDeadband { return .fade }
        if f < -BallFlight.severeCurveThreshold { return .hook }
        if f < -BallFlight.curveDeadband { return .draw }
        return .straight
    }

    /// A human-readable name for the shot, e.g. "Pull Draw" or "Push Fade".
    var shotName: String {
        let curveLabel = curve.label
        switch startSide {
        case .straight:
            return curve == .straight ? "Straight" : curveLabel
        case .left, .right:
            if curve == .straight { return startSide.rawValue }
            return "\(startSide.rawValue) \(curveLabel)"
        }
    }
}
