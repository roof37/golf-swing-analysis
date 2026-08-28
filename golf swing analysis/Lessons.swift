//
//  Lessons.swift
//  golf swing analysis
//
//  Curated teaching scenarios plus plain-language coaching that explains why a
//  given combination of face and path produces the shot it does. Aimed at
//  players learning the ball flight laws, right-handed convention throughout.
//

import Foundation

/// A pre-set teaching scenario the player can tap to load and study.
struct Lesson: Identifiable {
    let id = UUID()
    let title: String
    let faceAngle: Double
    let clubPath: Double
    /// One-line coaching summary of the cause.
    let coaching: String

    var flight: BallFlight {
        BallFlight(faceAngle: faceAngle, clubPath: clubPath)
    }
}

extension Lesson {
    /// The curriculum's complete nine-pattern ball-flight matrix.
    static let library: [Lesson] = [
        Lesson(
            title: "Pull Hook",
            faceAngle: -4, clubPath: -1,
            coaching: "Starts left and curves left."
        ),
        Lesson(
            title: "Pull",
            faceAngle: -4, clubPath: -4,
            coaching: "Starts left with no meaningful curve."
        ),
        Lesson(
            title: "Pull Slice",
            faceAngle: -2, clubPath: -7,
            coaching: "Starts left and curves right."
        ),
        Lesson(
            title: "Hook",
            faceAngle: -0.5, clubPath: 5,
            coaching: "Starts straight and curves left."
        ),
        Lesson(
            title: "Straight",
            faceAngle: 0, clubPath: 0,
            coaching: "Starts straight with no meaningful curve."
        ),
        Lesson(
            title: "Slice",
            faceAngle: 0.5, clubPath: -5,
            coaching: "Starts straight and curves right."
        ),
        Lesson(
            title: "Push Hook",
            faceAngle: 2, clubPath: 7,
            coaching: "Starts right and curves left."
        ),
        Lesson(
            title: "Push",
            faceAngle: 4, clubPath: 4,
            coaching: "Starts right with no meaningful curve."
        ),
        Lesson(
            title: "Push Slice",
            faceAngle: 4, clubPath: -3,
            coaching: "Starts right and curves right."
        )
    ]
}

// MARK: - Live coaching for any face/path combination

extension BallFlight {

    /// Why the ball starts where it does, in plain language.
    var startExplanation: String {
        let tail = "the face controls about 85% of where the ball starts."
        switch classification.startDirection {
        case .straight:
            return "The ball starts on target because the face is square at impact — \(tail)"
        case .right:
            return "The ball starts right of target because the face is open (pointing right) at impact — \(tail)"
        case .left:
            return "The ball starts left of target because the face is closed (pointing left) at impact — \(tail)"
        }
    }

    /// Why the ball curves the way it does, in plain language.
    var curveExplanation: String {
        switch classification.curveDirection {
        case .straight:
            return "It flies straight because the face is square to the path — there's nothing to tilt the spin axis."
        case .left:
            return "It curves left because the face is closed relative to the path (\(String(format: "%+.1f", faceToPath))°), tilting the spin axis left."
        case .right:
            return "It curves right because the face is open relative to the path (\(String(format: "%+.1f", faceToPath))°), tilting the spin axis right."
        }
    }
}
