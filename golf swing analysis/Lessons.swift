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
    /// Common shots players want to understand, ordered roughly easy → tricky.
    static let library: [Lesson] = [
        Lesson(
            title: "Straight",
            faceAngle: 0, clubPath: 0,
            coaching: "Face and path both point at the target, so the ball starts on line and never curves."
        ),
        Lesson(
            title: "The Slice",
            faceAngle: 6, clubPath: -4,
            coaching: "An out-to-in path with the face wide open to it tilts the spin axis hard right — the amateur's classic miss."
        ),
        Lesson(
            title: "The Pull",
            faceAngle: -4, clubPath: -4,
            coaching: "The face matches the out-to-in path, so the ball flies dead straight but starts left of target."
        ),
        Lesson(
            title: "The Push",
            faceAngle: 4, clubPath: 4,
            coaching: "Face and path agree going right (in-to-out), so the ball starts right and stays there."
        ),
        Lesson(
            title: "Power Draw",
            faceAngle: 2, clubPath: 6,
            coaching: "Start it right of target with an in-to-out path, face slightly closed to the path, and it curves gently back."
        ),
        Lesson(
            title: "The Hook",
            faceAngle: -6, clubPath: -1,
            coaching: "Face slammed shut relative to the path tilts the spin axis left — the ball dives hard to the left."
        )
    ]
}

// MARK: - Live coaching for any face/path combination

extension BallFlight {

    /// Why the ball starts where it does, in plain language.
    var startExplanation: String {
        let tail = "the face controls about 85% of where the ball starts."
        switch startSide {
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
        switch curve {
        case .straight:
            return "It flies straight because the face is square to the path — there's nothing to tilt the spin axis."
        case .draw, .hook:
            let strength = curve == .hook ? "a lot" : "gently"
            return "It curves \(strength) to the left because the face is closed relative to the path (\(String(format: "%+.1f", faceToPath))°), tilting the spin axis left."
        case .fade, .slice:
            let strength = curve == .slice ? "a lot" : "gently"
            return "It curves \(strength) to the right because the face is open relative to the path (\(String(format: "%+.1f", faceToPath))°), tilting the spin axis right."
        }
    }
}
