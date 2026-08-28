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
    /// Positive curves right; negative curves left.
    var faceToPath: Double {
        faceAngle - clubPath
    }
}

// MARK: - Classification

extension BallFlight {

    enum Direction: String, Codable {
        case left, straight, right

        var displayName: String { rawValue.capitalized }
    }

    enum CurveMagnitude: String, Codable {
        case none, slight, large
    }

    /// The curriculum's authoritative three-by-three ball-flight matrix.
    enum Pattern: String, Codable, CaseIterable {
        case pullHook = "Pull Hook"
        case pull = "Pull"
        case pullSlice = "Pull Slice"
        case hook = "Hook"
        case straight = "Straight"
        case slice = "Slice"
        case pushHook = "Push Hook"
        case push = "Push"
        case pushSlice = "Push Slice"
    }

    /// A single, reusable vocabulary for the observable parts of a shot.
    struct Classification: Equatable {
        let startDirection: Direction
        let curveDirection: Direction
        let curveMagnitude: CurveMagnitude
        let finishDirection: Direction
        let pattern: Pattern

        var shotName: String { pattern.rawValue }

        var startDescription: String { startDirection == .straight ? "Starts on line" : "Starts \(startDirection.rawValue)" }
        var curveDescription: String { curveDirection == .straight ? "Flies straight" : "Curves \(curveDirection.rawValue)" }
        var finishDescription: String { finishDirection == .straight ? "Finishes near target" : "Finishes \(finishDirection.rawValue)" }
        var summary: String { "\(startDescription) · \(curveDescription) · \(finishDescription)" }
    }

    /// Degrees of start direction within which we call the start "straight".
    static let startDeadband = 1.0
    /// Degrees of face-to-path within which we call the flight "straight".
    static let curveDeadband = 1.0
    /// Face-to-path magnitude beyond which a curve becomes a hook/slice.
    static let severeCurveThreshold = 5.0

    var classification: Classification {
        BallFlight.classify(
            startAngle: startDirection,
            curveAmount: faceToPath,
            finishAmount: startDirection + faceToPath
        )
    }

    var shotName: String { classification.shotName }

    /// Maps observed start and curve directions to exactly one curriculum term.
    static func classifyShot(startDirection: Direction, curveDirection: Direction) -> Pattern {
        switch (startDirection, curveDirection) {
        case (.left, .left): return .pullHook
        case (.left, .straight): return .pull
        case (.left, .right): return .pullSlice
        case (.straight, .left): return .hook
        case (.straight, .straight): return .straight
        case (.straight, .right): return .slice
        case (.right, .left): return .pushHook
        case (.right, .straight): return .push
        case (.right, .right): return .pushSlice
        }
    }

    static func classify(startAngle: Double, curveAmount: Double, finishAmount: Double) -> Classification {
        func direction(_ value: Double, deadband: Double) -> Direction {
            if value > deadband { return .right }
            if value < -deadband { return .left }
            return .straight
        }

        let curveDirection = direction(curveAmount, deadband: curveDeadband)
        let magnitude: CurveMagnitude
        if curveDirection == .straight { magnitude = .none }
        else if abs(curveAmount) > severeCurveThreshold { magnitude = .large }
        else { magnitude = .slight }

        let startDirection = direction(startAngle, deadband: startDeadband)
        return Classification(
            startDirection: startDirection,
            curveDirection: curveDirection,
            curveMagnitude: magnitude,
            finishDirection: direction(finishAmount, deadband: 1),
            pattern: classifyShot(startDirection: startDirection, curveDirection: curveDirection)
        )
    }
}

// MARK: - Curriculum-ready configuration

enum ShotLabMode: Codable { case explore, course }
enum ShotLabFocus: Codable { case startDirection, curvature, flightPatterns, clubFace, clubPath, faceToPath, launch, strike }
enum ShotParameter: String, Codable, Hashable { case clubFace, clubPath, attackAngle, dynamicLoft, strike, swingSpeed }

struct ShotLabConfiguration {
    var mode: ShotLabMode = .explore
    var focus: ShotLabFocus?
    var lockedParameters: Set<ShotParameter> = []
    var visibleParameters: Set<ShotParameter> = Set(ShotParameter.allCases)
    var initialState: SwingModel?

    static let explore = ShotLabConfiguration()
}

extension ShotParameter: CaseIterable {}
