//
//  SwingEngine.swift
//  golf swing analysis
//
//  The swing simulation engine. The downswing is a torque-driven double
//  pendulum (arm segment + club) in the swing plane — the classic physics-of-
//  golf model. The wrist is a latch: it holds the top-of-backswing cock angle
//  until the release point, then hinges freely. Transition Sequence sets the
//  release point, so "casting loses speed" is emergent physics, not a formula:
//  an early release lets the club peak before the ball and arrive slower.
//
//  Outputs:
//    • a timeline of GolferPose frames (scripted backswing → simulated
//      downswing → simulated release + scripted finish) for the renderer,
//    • impact numbers measured from the simulation (clubhead speed, attack
//      angle from the head's velocity vector at the ball),
//    • kinematic-sequence peak times measured from the simulated velocities.
//
//  Angles are measured from vertical-down in the front-on view; positive is
//  the trail side (top of backswing ≈ +150°), 0 points at the ball.
//

import Foundation

struct SwingEngine {

    // MARK: Output

    struct Output {
        /// Uniformly spaced poses across progress 0…1 (address → finish).
        var frames: [GolferPose]
        /// Realistic wall-clock time (s) of each frame. The downswing portion
        /// is the simulation's actual elapsed time, so transition violence is
        /// preserved; scripted phases use nominal durations.
        var frameTimes: [Double]
        /// Clubhead speed (mph) at each frame, for speed-colored trails.
        var headSpeeds: [Double]
        /// Clubhead speed at the ball (mph), measured from the simulation.
        var clubheadSpeed: Double
        /// In-plane clubhead velocity at the ball (m/s): toward the target
        /// along the plane, and up the plane. The swing-plane embedding turns
        /// these into world attack angle and club path.
        var impactVTarget: Double
        var impactVUp: Double
        /// Normalized (0…1) times where each segment's speed peaks.
        var peakTimes: [Double]     // pelvis, torso, arm, club
        /// Progress value where impact happens (fixed by construction).
        static let impactProgress = 0.72
        static let topProgress = 0.55
    }

    // MARK: Physical constants

    /// Effective arm-segment mass (kg) and hub-to-hands length (m).
    private static let armMass = 6.5
    private static let armLength = 0.62
    private static let gravity = 9.81
    /// Wrist cock at the top (rad, ~75°).
    private static let topCock = 75.0 * .pi / 180
    /// Arm angle at the top (rad from vertical, trail side, ~150°).
    private static let topArm = 150.0 * .pi / 180
    private static let dt = 0.0004
    private static let mphPerMs = 2.23694

    /// Club-dependent pendulum parameters. The head-end mass folds in the
    /// shaft's contribution; shorter/heavier iron geometry is why the same
    /// body swings an iron slower than a driver.
    private static func clubParameters(_ club: Biomechanics.Club) -> (length: Double, mass: Double, baseTorque: Double) {
        switch club {
        case .driver: return (club.pendulumLength, 0.32, 285)
        case .iron: return (club.pendulumLength, 0.40, 230)
        }
    }

    /// Effective arm-segment length (m) — exposed for the stage renderer.
    static var armSegmentLength: Double { armLength }

    // MARK: Simulation inputs derived from the body

    private struct Inputs {
        var torque: Double          // hub drive torque (N·m)
        var releaseAngle: Double    // arm angle (rad) where the wrist latch opens
        var cock: Double            // wrist cock held until release (rad)
        var clubLength: Double
        var clubMass: Double
        var ballOffset: Double      // ball x relative to arc bottom (m, + trail side)
    }

    private static func inputs(for bio: Biomechanics) -> Inputs {
        let seq = bio.transitionSequence / 100
        let separation = bio.pelvisRotation - bio.thoraxRotation
        let coil = min(35, max(-10, separation))
        let club = clubParameters(bio.club)

        // Coil and pressure feed the engine's torque; the sequence decides how
        // much of that drive arrives as organized rotation.
        let torque = club.baseTorque
            * (1 + 0.0060 * coil * seq)
            * (0.90 + 0.0020 * (bio.leadPressure - 50))
            * (0.80 + 0.20 * seq)

        // Release point: an efficient transition holds the latch deep into the
        // downswing; a poor one throws it from the top.
        let late = 38.0 * .pi / 180
        let early = topArm * 0.94
        let releaseAngle = early + (late - early) * pow(seq, 0.8)

        // A cupped wrist carries a touch more cock; a bowed one less.
        let cock = topCock + bio.leadWrist * 0.004

        // Ball sits `lowPointPastBall` cm behind the arc bottom (+ = bottom
        // past the ball → descending). Same low point that drives lean/loft.
        let lowPointAhead = SwingMechanicsEngine.lowPointAhead(
            leadPressure: bio.leadPressure, sideBend: bio.sideBend, sequenceGate: seq)
        let ballOffset = (lowPointAhead - bio.club.ballForward) * 0.01

        return Inputs(torque: torque, releaseAngle: releaseAngle, cock: cock,
                      clubLength: club.length, clubMass: club.mass, ballOffset: ballOffset)
    }

    // MARK: Downswing simulation

    /// One sample of the simulated downswing.
    private struct Sample {
        var t: Double
        var arm: Double      // a1 (rad)
        var club: Double     // a2 (rad)
        var armSpeed: Double
        var clubSpeed: Double
        var headX: Double    // head position (m, + trail side)
        var headVTarget: Double  // head velocity toward the target (m/s)
        var headVUp: Double      // head velocity upward (m/s)
    }

    private struct SimResult {
        var samples: [Sample]
        var impactIndex: Int
        var speedMPH: Double
    }

    /// Integrates top → past the arc bottom (plus a short follow-through) with
    /// RK4, then locates the ball on the head's actual trajectory.
    private static func simulate(_ p: Inputs) -> SimResult {
        let L1 = armLength, L2 = p.clubLength
        let m1 = armMass, m2 = p.clubMass

        // State: (a1, a2, w1, w2). Latched phase pins a2 = a1 + cock.
        var a1 = topArm, a2 = topArm + p.cock
        var w1 = 0.0, w2 = 0.0
        var released = false
        var releaseTime = 0.0
        var t = 0.0
        var samples: [Sample] = []

        // Rigid (latched) inertia: both masses turn as one body about the hub.
        let r2 = sqrt(L1 * L1 + L2 * L2 + 2 * L1 * L2 * cos(p.cock))
        let rigidInertia = m1 * L1 * L1 + m2 * r2 * r2

        func gravityTorqueRigid(_ a: Double) -> Double {
            -gravity * (m1 * L1 * sin(a) + m2 * (L1 * sin(a) + L2 * sin(a + p.cock)))
        }

        // The body's push fades after the release — the deceleration phase of a
        // real kinematic sequence. An early (cast) release therefore also cuts
        // the drive short, which is a big part of why casting costs speed.
        func driveTorque(_ time: Double) -> Double {
            guard released else { return p.torque }
            return p.torque * max(0, 1 - (time - releaseTime) / 0.09)
        }

        /// 2-DOF accelerations once the latch is open.
        func accelerations(_ tau: Double, _ a1: Double, _ a2: Double, _ w1: Double, _ w2: Double) -> (Double, Double) {
            let delta = a1 - a2
            let m11 = (m1 + m2) * L1 * L1
            let m12 = m2 * L1 * L2 * cos(delta)
            let m22 = m2 * L2 * L2
            let rhs1 = -tau - m2 * L1 * L2 * sin(delta) * w2 * w2 - (m1 + m2) * gravity * L1 * sin(a1)
            let rhs2 = m2 * L1 * L2 * sin(delta) * w1 * w1 - m2 * gravity * L2 * sin(a2)
            let det = m11 * m22 - m12 * m12
            return ((rhs1 * m22 - rhs2 * m12) / det, (rhs2 * m11 - rhs1 * m12) / det)
        }

        func record() {
            let x = L1 * sin(a1) + L2 * sin(a2)
            let vx = L1 * w1 * cos(a1) + L2 * w2 * cos(a2)
            let vyDown = -L1 * w1 * sin(a1) - L2 * w2 * sin(a2)
            samples.append(Sample(t: t, arm: a1, club: a2,
                                  armSpeed: abs(w1), clubSpeed: abs(w2),
                                  headX: x, headVTarget: -vx, headVUp: -vyDown))
        }

        record()
        var bottomTime = -1.0

        while t < 0.9 {
            if !released && a1 <= p.releaseAngle {
                released = true
                releaseTime = t
                a2 = a1 + p.cock
                w2 = w1
            }

            let tau = driveTorque(t)
            if !released {
                // Single rigid DOF, RK4 on (a1, w1).
                func acc(_ a: Double, _ w: Double) -> Double {
                    (-tau + gravityTorqueRigid(a)) / rigidInertia
                }
                let k1a = w1, k1w = acc(a1, w1)
                let k2a = w1 + 0.5 * dt * k1w, k2w = acc(a1 + 0.5 * dt * k1a, k2a)
                let k3a = w1 + 0.5 * dt * k2w, k3w = acc(a1 + 0.5 * dt * k2a, k3a)
                let k4a = w1 + dt * k3w, k4w = acc(a1 + dt * k3a, k4a)
                a1 += dt / 6 * (k1a + 2 * k2a + 2 * k3a + k4a)
                w1 += dt / 6 * (k1w + 2 * k2w + 2 * k3w + k4w)
                a2 = a1 + p.cock
                w2 = w1
            } else {
                // Full double pendulum, RK4 on (a1, a2, w1, w2).
                func deriv(_ s: (Double, Double, Double, Double)) -> (Double, Double, Double, Double) {
                    let (sa1, sa2, sw1, sw2) = s
                    let (d1, d2) = accelerations(tau, sa1, sa2, sw1, sw2)
                    return (sw1, sw2, d1, d2)
                }
                let s0 = (a1, a2, w1, w2)
                let k1 = deriv(s0)
                let k2 = deriv((a1 + 0.5 * dt * k1.0, a2 + 0.5 * dt * k1.1, w1 + 0.5 * dt * k1.2, w2 + 0.5 * dt * k1.3))
                let k3 = deriv((a1 + 0.5 * dt * k2.0, a2 + 0.5 * dt * k2.1, w1 + 0.5 * dt * k2.2, w2 + 0.5 * dt * k2.3))
                let k4 = deriv((a1 + dt * k3.0, a2 + dt * k3.1, w1 + dt * k3.2, w2 + dt * k3.3))
                a1 += dt / 6 * (k1.0 + 2 * k2.0 + 2 * k3.0 + k4.0)
                a2 += dt / 6 * (k1.1 + 2 * k2.1 + 2 * k3.1 + k4.1)
                w1 += dt / 6 * (k1.2 + 2 * k2.2 + 2 * k3.2 + k4.2)
                w2 += dt / 6 * (k1.3 + 2 * k2.3 + 2 * k3.3 + k4.3)
            }

            t += dt
            record()

            // Arc bottom: the head stops descending while it's being delivered.
            if bottomTime < 0, released, a1 < 1.0,
               let prev = samples.dropLast().last, prev.headVUp < 0, samples.last!.headVUp >= 0 {
                bottomTime = t
            }

            // Keep a short simulated follow-through after the bottom.
            if bottomTime > 0 && t - bottomTime > 0.10 { break }
        }

        // Bottom never detected (degenerate settings): use the fastest sample.
        let bottomIndex = bottomTime > 0
            ? min(samples.count - 1, Int(bottomTime / dt))
            : (samples.indices.max { samples[$0].clubSpeed < samples[$1].clubSpeed } ?? samples.count - 1)

        // Ball position on the trajectory: `ballOffset` trailward of the bottom
        // (+ = arc bottoms past the ball → the head meets the ball descending).
        let ballX = samples[bottomIndex].headX + p.ballOffset
        var impactIndex = bottomIndex
        if p.ballOffset > 0 {
            // Descending strike: walk back to where the head crossed ballX.
            while impactIndex > 1, samples[impactIndex].headX < ballX,
                  samples[bottomIndex].t - samples[impactIndex].t < 0.05 { impactIndex -= 1 }
        } else if p.ballOffset < 0 {
            // Ascending strike: walk forward past the bottom.
            while impactIndex < samples.count - 2, samples[impactIndex].headX > ballX,
                  samples[impactIndex].t - samples[bottomIndex].t < 0.05 { impactIndex += 1 }
        }

        let hit = samples[impactIndex]
        let speed = sqrt(hit.headVTarget * hit.headVTarget + hit.headVUp * hit.headVUp) * mphPerMs

        return SimResult(samples: samples, impactIndex: impactIndex, speedMPH: speed)
    }

    // MARK: Timeline assembly

    /// Builds the full 0…1 timeline: scripted backswing, simulated downswing
    /// (normalized so impact lands at `impactProgress`), simulated release
    /// blending into a scripted finish.
    static func run(_ bio: Biomechanics) -> Output {
        let p = inputs(for: bio)
        let sim = simulate(p)

        let impactW = (bio.leadPressure - 50) / 45
        let topThorax = -95 + bio.thoraxRotation * 0.6
        let topPelvis = -50 + bio.pelvisRotation * 0.5
        let topWeight = impactW < 0.12 ? 0.62 : 0.20
        let seq = bio.transitionSequence / 100

        let tTop = Output.topProgress
        let tImpact = Output.impactProgress
        let tImpactSim = sim.samples[sim.impactIndex].t
        let tEndSim = sim.samples.last!.t
        // Simulated follow-through occupies progress up to this point.
        let tCoast = min(0.86, tImpact + (tEndSim - tImpactSim) / max(tImpactSim, 0.01) * (tImpact - tTop))

        let degrees = 180.0 / Double.pi

        func simSample(at time: Double) -> Sample {
            let clamped = max(0, min(time, tEndSim))
            let i = min(sim.samples.count - 1, Int(clamped / dt))
            return sim.samples[i]
        }

        /// Body rotation during the downswing: the pelvis leads and the thorax
        /// trails by an amount set by the sequence quality.
        func body(atDownswing f: Double) -> (hip: Double, shoulder: Double, weight: Double) {
            let pelvisF = pow(f, max(0.45, 1.0 - 0.45 * seq))
            let thoraxF = pow(f, 1.0 + 0.6 * seq)
            return (topPelvis + (bio.pelvisRotation - topPelvis) * pelvisF,
                    topThorax + (bio.thoraxRotation - topThorax) * thoraxF,
                    topWeight + (impactW - topWeight) * pow(f, 0.8))
        }

        func pose(at progress: Double) -> GolferPose {
            var shoulder = 0.0, hip = 0.0, weight = 0.45, wrist = bio.leadWrist
            var arm = 0.0, club = 0.0

            if progress < tTop {
                // Scripted backswing.
                let f = smooth(progress / tTop)
                shoulder = lerp(0, topThorax, f)
                hip = lerp(0, topPelvis, f)
                weight = lerp(0.45, topWeight, f)
                wrist = lerp(bio.leadWrist, bio.leadWrist + 28, f)
                arm = lerp(0, topArm * degrees, f)
                club = lerp(0, (topArm + topCock) * degrees, f)
            } else if progress < tCoast {
                // Simulated downswing + release, warped so impact = tImpact.
                let simTime = progress <= tImpact
                    ? (progress - tTop) / (tImpact - tTop) * tImpactSim
                    : tImpactSim + (progress - tImpact) / max(tCoast - tImpact, 0.001) * (tEndSim - tImpactSim)
                let s = simSample(at: simTime)
                let f = min(1, (progress - tTop) / (tImpact - tTop))
                let b = body(atDownswing: f)
                shoulder = b.shoulder; hip = b.hip; weight = b.weight
                wrist = lerp(bio.leadWrist + 28, bio.leadWrist, f)
                arm = s.arm * degrees
                club = s.club * degrees
            } else {
                // Scripted finish, continuing from the last simulated frame.
                let last = sim.samples.last!
                let f = smooth((progress - tCoast) / max(1 - tCoast, 0.001))
                shoulder = lerp(bio.thoraxRotation, bio.thoraxRotation + 95, f)
                hip = lerp(bio.pelvisRotation, bio.pelvisRotation + 70, f)
                weight = lerp(impactW, max(0.92, impactW), f)
                wrist = lerp(bio.leadWrist, bio.leadWrist - 45, f)
                arm = lerp(last.arm * degrees, -150, f)
                club = lerp(last.club * degrees, -210, f)
            }

            return GolferPose(shoulder: shoulder, hip: hip, spine: bio.sideBend,
                              weight: weight, armAngle: arm, clubAngle: club,
                              wrist: wrist, swinging: true, progress: progress)
        }

        let frameCount = 240
        let frames = (0...frameCount).map { pose(at: Double($0) / Double(frameCount)) }

        // Realistic clock: scripted phases get nominal durations, the
        // downswing and coast get the simulation's actual elapsed time. A
        // poor sequence genuinely takes longer to reach the ball, and that
        // difference survives into playback.
        let backswingDuration = 0.85
        let finishDuration = 0.55
        func time(at progress: Double) -> Double {
            if progress <= tTop {
                return progress / tTop * backswingDuration
            }
            if progress <= tImpact {
                return backswingDuration + (progress - tTop) / (tImpact - tTop) * tImpactSim
            }
            if progress <= tCoast {
                return backswingDuration + tImpactSim
                    + (progress - tImpact) / max(tCoast - tImpact, 0.001) * (tEndSim - tImpactSim)
            }
            return backswingDuration + tEndSim
                + (progress - tCoast) / max(1 - tCoast, 0.001) * finishDuration
        }
        let frameTimes = (0...frameCount).map { time(at: Double($0) / Double(frameCount)) }

        // Per-frame clubhead speed from central differences over the in-plane
        // head positions — one honest code path across scripted and simulated
        // phases, using the same clock the playback uses.
        let clubLength = p.clubLength
        func headPoint(_ f: GolferPose) -> (x: Double, y: Double) {
            let a = f.armAngle * .pi / 180, c = f.clubAngle * .pi / 180
            return (armLength * sin(a) + clubLength * sin(c),
                    -(armLength * cos(a) + clubLength * cos(c)))
        }
        let headPoints = frames.map(headPoint)
        let headSpeeds = (0...frameCount).map { i -> Double in
            let j = max(0, i - 1), k = min(frameCount, i + 1)
            let dt = frameTimes[k] - frameTimes[j]
            guard dt > 1e-6 else { return 0 }
            let dx = headPoints[k].x - headPoints[j].x
            let dy = headPoints[k].y - headPoints[j].y
            return sqrt(dx * dx + dy * dy) / dt * mphPerMs
        }

        let hit = sim.samples[sim.impactIndex]
        return Output(frames: frames,
                      frameTimes: frameTimes,
                      headSpeeds: headSpeeds,
                      clubheadSpeed: sim.speedMPH,
                      impactVTarget: hit.headVTarget,
                      impactVUp: hit.headVUp,
                      peakTimes: peakTimes(sim: sim, seq: seq))
    }

    /// Kinematic-sequence peaks: arm and club are measured from the simulated
    /// angular speeds; pelvis and torso from the scripted body channels.
    private static func peakTimes(sim: SimResult, seq: Double) -> [Double] {
        let tImpactSim = sim.samples[sim.impactIndex].t
        guard tImpactSim > 0 else { return [0.45, 0.5, 0.55, 0.6] }

        func normalized(_ t: Double) -> Double {
            max(0.05, min(0.95, 0.1 + 0.8 * t / tImpactSim))
        }
        let delivered = sim.samples.prefix(sim.impactIndex + 1)
        let armPeak = delivered.max { $0.armSpeed < $1.armSpeed }
        // The club's peak is the head's linear speed: a cast peaks before the ball.
        func headSpeed(_ s: Sample) -> Double { s.headVTarget * s.headVTarget + s.headVUp * s.headVUp }
        let clubPeak = delivered.max { headSpeed($0) < headSpeed($1) }

        // Scripted body channels peak early in proportion to sequence quality.
        let pelvis = 0.12 + 0.10 * (1 - seq)
        let torso = pelvis + 0.10 + 0.12 * seq
        return [pelvis, torso,
                normalized(armPeak?.t ?? 0.5 * tImpactSim),
                normalized(clubPeak?.t ?? tImpactSim)]
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    // MARK: Memoized access

    /// Small MRU cache. Sliders change one value at a time, but the stage can
    /// render a ghost body alongside the live one, so a single slot would
    /// thrash — a few slots keep both resident. Thread-safe for previews.
    private final class Memo: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(key: Biomechanics, value: Output)] = []

        func output(for bio: Biomechanics) -> Output {
            lock.lock()
            defer { lock.unlock() }
            if let i = entries.firstIndex(where: { $0.key == bio }) {
                let hit = entries.remove(at: i)
                entries.insert(hit, at: 0)
                return hit.value
            }
            let out = SwingEngine.run(bio)
            entries.insert((bio, out), at: 0)
            if entries.count > 4 { entries.removeLast() }
            return out
        }
    }

    private static let memo = Memo()

    /// The simulation for a body, recomputed only when the inputs change.
    static func output(for bio: Biomechanics) -> Output {
        memo.output(for: bio)
    }
}

extension SwingEngine.Output {
    /// Total realistic duration (s) of the swing at 1× speed.
    var duration: Double { frameTimes.last ?? 0 }

    /// Progress (0…1) reached after `elapsed` seconds of realistic playback —
    /// the inverse of the per-frame clock, so the downswing plays at the
    /// simulation's actual pace instead of a uniform crawl.
    func progress(atTime elapsed: Double) -> Double {
        guard let total = frameTimes.last, total > 0 else { return 1 }
        if elapsed <= 0 { return 0 }
        if elapsed >= total { return 1 }
        var lo = 0, hi = frameTimes.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if frameTimes[mid] <= elapsed { lo = mid } else { hi = mid }
        }
        let span = frameTimes[hi] - frameTimes[lo]
        let f = span > 1e-9 ? (elapsed - frameTimes[lo]) / span : 0
        return (Double(lo) + f) / Double(frameTimes.count - 1)
    }

    /// The pose for a scrubber/clock progress value, interpolated between
    /// timeline frames.
    func pose(at progress: Double) -> GolferPose {
        let clamped = max(0, min(1, progress))
        let x = clamped * Double(frames.count - 1)
        let i = min(frames.count - 2, Int(x))
        let f = x - Double(i)
        let a = frames[i], b = frames[i + 1]
        func mix(_ p: Double, _ q: Double) -> Double { p + (q - p) * f }
        return GolferPose(shoulder: mix(a.shoulder, b.shoulder),
                          hip: mix(a.hip, b.hip),
                          spine: mix(a.spine, b.spine),
                          weight: mix(a.weight, b.weight),
                          armAngle: mix(a.armAngle, b.armAngle),
                          clubAngle: mix(a.clubAngle, b.clubAngle),
                          wrist: mix(a.wrist, b.wrist),
                          swinging: true, progress: clamped)
    }
}
