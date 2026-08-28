//
//  golf_swing_analysisTests.swift
//  golf swing analysisTests
//
//  Created by Ralph Halabi on 6/27/26.
//

import Testing
@testable import golf_swing_analysis

@MainActor
struct golf_swing_analysisTests {

    @Test func mechanicsOutputFeedsBiomechanicsProperties() async throws {
        let biomechanics = Biomechanics()
        let output = SwingMechanicsEngine.output(for: biomechanics)

        #expect(output.impact.faceAngle == biomechanics.faceAngle)
        #expect(output.impact.clubPath == biomechanics.clubPath)
        #expect(output.impact.angleOfAttack == biomechanics.angleOfAttack)
        #expect(output.impact.dynamicLoft == biomechanics.dynamicLoft)
        #expect(output.impact.shaftLean == biomechanics.shaftLean)
        #expect(output.impact.swingSpeed == biomechanics.swingSpeed)
    }

    @Test func tourMoveDeliversMoreSpeedThanCastAndScoop() async throws {
        let tour = biomechanics(named: "Tour Move")
        let cast = biomechanics(named: "Cast & Scoop")

        #expect(tour.mechanics.impact.swingSpeed > cast.mechanics.impact.swingSpeed)
        #expect(tour.mechanics.diagnostics.sequenceGate > cast.mechanics.diagnostics.sequenceGate)
    }

    @Test func overTheTopPatternProducesLeftwardPath() async throws {
        let overTheTop = biomechanics(named: "Over the Top")

        #expect(overTheTop.mechanics.diagnostics.overTheTop > 0)
        #expect(overTheTop.mechanics.impact.clubPath < 0)
    }

    /// D-plane geometry: with the swing on an inclined plane, hitting down
    /// (impact before the arc bottom) pushes the path in-to-out of the
    /// plane's own direction; hitting up pulls it out-to-in.
    @Test func attackAngleShiftsPathAlongThePlane() async throws {
        var iron = Biomechanics()
        iron.club = .iron          // ball centered → descending strike
        let ironOut = iron.mechanics
        #expect(ironOut.impact.angleOfAttack < 0)
        #expect(ironOut.impact.clubPath > ironOut.plane.deliveryDegrees)

        var driver = Biomechanics()
        driver.club = .driver      // ball forward → ascending strike
        let driverOut = driver.mechanics
        #expect(driverOut.impact.angleOfAttack > 0)
        #expect(driverOut.impact.clubPath < driverOut.plane.deliveryDegrees)
    }

    /// An over-the-top transition shifts the downswing onto a plane left of
    /// the backswing plane — the loop the down-the-line view draws.
    @Test func overTheTopShiftsTheDownswingPlaneLeft() async throws {
        let overTheTop = biomechanics(named: "Over the Top").mechanics
        let tour = biomechanics(named: "Tour Move").mechanics

        let ottLoop = overTheTop.plane.backswingDegrees - overTheTop.plane.deliveryDegrees
        let tourLoop = tour.plane.backswingDegrees - tour.plane.deliveryDegrees
        #expect(ottLoop > 5)
        #expect(ottLoop > tourLoop)
    }

    /// The speed-colored trail's teaching claim: with the same body, an early
    /// release has already built most of its (lower) impact speed two-thirds
    /// of the way down, while a good sequence keeps accelerating into the
    /// ball — speed arrives late.
    @Test func poorSequenceSpendsItsSpeedEarly() async throws {
        func builtFraction(_ bio: Biomechanics, at progress: Double) -> Double {
            let speeds = bio.engine.headSpeeds
            let n = Double(speeds.count - 1)
            let impact = speeds[Int(SwingEngine.Output.impactProgress * n)]
            return speeds[Int(progress * n)] / impact
        }
        var good = Biomechanics()
        good.transitionSequence = 92
        var poor = good
        poor.transitionSequence = 30

        #expect(builtFraction(poor, at: 0.68) > builtFraction(good, at: 0.68) + 0.05)
        #expect(good.swingSpeed > poor.swingSpeed + 10)

        // The good sequence's delivered speed peaks at the ball, not before.
        let speeds = good.engine.headSpeeds
        let impactIndex = Int(SwingEngine.Output.impactProgress * Double(speeds.count - 1))
        let deliveredPeak = (0...impactIndex).max { speeds[$0] < speeds[$1] } ?? 0
        #expect(impactIndex - deliveredPeak <= 3)
    }

    /// The realistic clock: frame times increase monotonically, and the
    /// downswing occupies far less wall time than the backswing.
    @Test func frameClockIsMonotonicAndTransientIsFast() async throws {
        let output = Biomechanics().engine
        #expect(output.frameTimes.count == output.frames.count)
        #expect(zip(output.frameTimes, output.frameTimes.dropFirst()).allSatisfy { $0 <= $1 })

        let frameCount = Double(output.frameTimes.count - 1)
        let topTime = output.frameTimes[Int(SwingEngine.Output.topProgress * frameCount)]
        let impactTime = output.frameTimes[Int(SwingEngine.Output.impactProgress * frameCount)]
        #expect(impactTime - topTime < topTime * 0.6)
        #expect(output.duration > 1.0)
    }

    @Test func mechanicsOutputCanProduceShotModel() async throws {
        let biomechanics = biomechanics(named: "Tour Move")
        let shot = biomechanics.mechanics.ballFlight

        #expect(shot.swingSpeed == biomechanics.swingSpeed)
        #expect(shot.dynamicLoft == biomechanics.dynamicLoft)
        #expect(shot.carryDistance > 0)
    }

    private func biomechanics(named name: String) -> Biomechanics {
        var biomechanics = Biomechanics()
        let fault = BodyFault.library.first { $0.name == name }
        fault?.apply(to: &biomechanics)
        return biomechanics
    }
}
