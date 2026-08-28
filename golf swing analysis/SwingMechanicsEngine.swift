//
//  SwingMechanicsEngine.swift
//  golf swing analysis
//
//  Pure mechanics pipeline for the Swing Lab. SwiftUI owns controls and
//  rendering; this engine owns the deterministic body -> club -> ball output.
//

import Foundation

struct SwingMechanicsInput: Equatable {
    var club: Biomechanics.Club
    var pelvisRotation: Double
    var thoraxRotation: Double
    var leadPressure: Double
    var sideBend: Double
    var leadWrist: Double
    var transitionSequence: Double

    init(_ biomechanics: Biomechanics) {
        club = biomechanics.club
        pelvisRotation = biomechanics.pelvisRotation
        thoraxRotation = biomechanics.thoraxRotation
        leadPressure = biomechanics.leadPressure
        sideBend = biomechanics.sideBend
        leadWrist = biomechanics.leadWrist
        transitionSequence = biomechanics.transitionSequence
    }
}

struct ImpactDelivery: Equatable {
    var faceAngle: Double
    var clubPath: Double
    var angleOfAttack: Double
    var dynamicLoft: Double
    var shaftLean: Double
    var swingSpeed: Double
}

struct SwingDiagnostics: Equatable {
    var separation: Double
    var sequenceGate: Double
    var earnedThorax: Double
    var overTheTop: Double
    var lowPointAhead: Double
    var lowPointPastBall: Double
    var peakTimes: [Double]
}

struct SwingMechanicsOutput {
    var timeline: SwingEngine.Output
    var impact: ImpactDelivery
    var diagnostics: SwingDiagnostics
    var ballFlight: SwingModel
    /// The inclined plane the swing was delivered on — the renderer projects
    /// the figure and trail through the same plane the numbers came from.
    var plane: SwingPlane
}

struct SwingMechanicsEngine {

    /// Where the swing arc bottoms out, in cm ahead of stance center. Shared
    /// with SwingEngine (which positions the ball on the simulated arc from
    /// it) so the two can never drift apart.
    static func lowPointAhead(leadPressure: Double, sideBend: Double, sequenceGate: Double) -> Double {
        (leadPressure - 60) * 0.4 * (0.5 + 0.5 * sequenceGate) - (sideBend - 8) * 0.5
    }

    static func evaluate(_ biomechanics: Biomechanics) -> SwingMechanicsOutput {
        let input = SwingMechanicsInput(biomechanics)
        let sequenceGate = input.transitionSequence / 100
        let separation = input.pelvisRotation - input.thoraxRotation
        let earnedThorax = 45 * sequenceGate
        let overTheTop = max(0, input.thoraxRotation - earnedThorax)
        let lowPointAhead = lowPointAhead(
            leadPressure: input.leadPressure, sideBend: input.sideBend, sequenceGate: sequenceGate)
        let lowPointPastBall = lowPointAhead - input.club.ballForward

        let timeline = SwingEngine.output(for: biomechanics)

        // Delivery geometry: the body sets the plane, the simulation says
        // where on the arc the ball was met, and path/attack angle fall out
        // of projecting that impact velocity through the plane.
        let plane = SwingPlane.make(club: input.club,
                                    pelvisRotation: input.pelvisRotation,
                                    thoraxRotation: input.thoraxRotation,
                                    sequenceGate: sequenceGate,
                                    overTheTop: overTheTop)
        let clubPath = plane.clubPath(target: timeline.impactVTarget, up: timeline.impactVUp)
        let angleOfAttack = max(-8, min(8, plane.attackAngle(target: timeline.impactVTarget,
                                                             up: timeline.impactVUp)))

        let faceAngle = deliveredFaceAngle(input: input, sequenceGate: sequenceGate)
        let shaftLean = max(-2, lowPointAhead * 0.7 - input.leadWrist * 0.15 + input.club.leanBias)
        let dynamicLoft = max(4, input.club.staticLoft - shaftLean * 0.55 + input.leadWrist * 0.35)

        let impact = ImpactDelivery(
            faceAngle: faceAngle,
            clubPath: clubPath,
            angleOfAttack: angleOfAttack,
            dynamicLoft: dynamicLoft,
            shaftLean: shaftLean,
            swingSpeed: timeline.clubheadSpeed
        )

        var shot = SwingModel()
        shot.faceAngle = impact.faceAngle
        shot.clubPath = impact.clubPath
        shot.angleOfAttack = impact.angleOfAttack
        shot.dynamicLoft = impact.dynamicLoft
        shot.shaftLean = impact.shaftLean
        shot.swingSpeed = impact.swingSpeed

        let diagnostics = SwingDiagnostics(
            separation: separation,
            sequenceGate: sequenceGate,
            earnedThorax: earnedThorax,
            overTheTop: overTheTop,
            lowPointAhead: lowPointAhead,
            lowPointPastBall: lowPointPastBall,
            peakTimes: timeline.peakTimes
        )

        return SwingMechanicsOutput(
            timeline: timeline,
            impact: impact,
            diagnostics: diagnostics,
            ballFlight: shot,
            plane: plane
        )
    }

    private static func deliveredFaceAngle(input: SwingMechanicsInput, sequenceGate: Double) -> Double {
        let flip = (1 - sequenceGate) * max(0, 62 - input.leadPressure) * 0.12
        return input.leadWrist * 0.9 + flip
    }

    /// Small MRU cache — a few slots so the stage's ghost body and the live
    /// body can both stay resident without recomputing every frame.
    private final class Memo: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(key: Biomechanics, value: SwingMechanicsOutput)] = []

        func output(for biomechanics: Biomechanics) -> SwingMechanicsOutput {
            lock.lock()
            defer { lock.unlock() }
            if let i = entries.firstIndex(where: { $0.key == biomechanics }) {
                let hit = entries.remove(at: i)
                entries.insert(hit, at: 0)
                return hit.value
            }
            let output = SwingMechanicsEngine.evaluate(biomechanics)
            entries.insert((biomechanics, output), at: 0)
            if entries.count > 4 { entries.removeLast() }
            return output
        }
    }

    private static let memo = Memo()

    static func output(for biomechanics: Biomechanics) -> SwingMechanicsOutput {
        memo.output(for: biomechanics)
    }
}
