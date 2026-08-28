//
//  SwingPlane.swift
//  golf swing analysis
//
//  The inclined plane the swing is delivered on. The pendulum simulation is
//  2D *in the plane*; embedding that plane in 3D is what turns in-plane
//  motion into real-world delivery numbers:
//
//    • Club path becomes geometry, not a formula. The plane's horizontal
//      direction sets the baseline; where impact happens on the arc does the
//      rest. Hitting down (before the arc bottom) pushes the path in-to-out,
//      hitting up pulls it out-to-in — the classic D-plane coupling.
//    • Over the top becomes visible. A poor transition shifts the club onto
//      a different (leftward) plane for the downswing, so a down-the-line
//      view shows the loop instead of just a red number.
//
//  World frame: +x toward the target, +y up, +z from the golfer out toward
//  the ball line. Right-handed golfer. Angles about vertical are positive
//  toward in-to-out (aimed right of target).
//

import Foundation

struct SwingPlane: Equatable {

    /// Plane inclination above horizontal (rad). Shorter clubs stand closer
    /// to the ball, so their plane is steeper.
    var tilt: Double
    /// Horizontal swing direction at delivery (rad, + = in-to-out).
    var deliveryDirection: Double
    /// Horizontal direction the backswing tracks (rad). When the transition
    /// is over the top, the downswing plane sits left of this — the loop.
    var backswingDirection: Double

    // MARK: Construction from the body

    /// Where the body delivers the plane. Pelvis clearance earns room to
    /// swing out, a genuinely closed thorax holds the direction rightward,
    /// and thorax rotation that outran the sequence drags the whole plane
    /// left — over the top.
    static func make(club: Biomechanics.Club,
                     pelvisRotation: Double,
                     thoraxRotation: Double,
                     sequenceGate: Double,
                     overTheTop: Double) -> SwingPlane {
        let clearance = (pelvisRotation - 40) * 0.10 * (0.5 + 0.5 * sequenceGate)
        let closedThorax = max(0, -thoraxRotation) * 0.15
        let deliveryDegrees = clearance + closedThorax - 0.25 * overTheTop + club.swingDirectionBias
        // The backswing tracks slightly inside; an over-the-top transition
        // means the club came DOWN well left of where it went UP.
        let loopDegrees = min(14, 1.0 + 0.30 * overTheTop)
        return SwingPlane(tilt: club.planeTilt * .pi / 180,
                          deliveryDirection: deliveryDegrees * .pi / 180,
                          backswingDirection: (deliveryDegrees + loopDegrees) * .pi / 180)
    }

    // MARK: Basis vectors

    /// In-plane axes embedded in the world for a horizontal direction δ:
    /// `u` points down-target along the plane, `v` points up the plane
    /// (from the ball toward the hands).
    static func basis(tilt: Double, direction: Double) -> (u: SIMD3<Double>, v: SIMD3<Double>) {
        let u = SIMD3(cos(direction), 0, sin(direction))
        let v = SIMD3(cos(tilt) * sin(direction), sin(tilt), -cos(tilt) * cos(direction))
        return (u, v)
    }

    /// The horizontal plane direction at a swing progress value: backswing
    /// direction going up, blending onto the delivery direction through the
    /// transition (top of backswing is at progress 0.55).
    func direction(at progress: Double) -> Double {
        let blendStart = 0.52, blendEnd = 0.62
        if progress <= blendStart { return backswingDirection }
        if progress >= blendEnd { return deliveryDirection }
        let x = (progress - blendStart) / (blendEnd - blendStart)
        let s = x * x * (3 - 2 * x)
        return backswingDirection + (deliveryDirection - backswingDirection) * s
    }

    /// Plane basis at a swing progress value (includes the transition shift).
    func basis(at progress: Double) -> (u: SIMD3<Double>, v: SIMD3<Double>) {
        Self.basis(tilt: tilt, direction: direction(at: progress))
    }

    // MARK: Delivery numbers

    /// World velocity of an in-plane clubhead velocity at delivery.
    func worldVelocity(target: Double, up: Double) -> SIMD3<Double> {
        let b = Self.basis(tilt: tilt, direction: deliveryDirection)
        return target * b.u + up * b.v
    }

    /// Geometric club path (deg, + = in-to-out) from the in-plane impact
    /// velocity: the horizontal direction the head is actually traveling.
    func clubPath(target: Double, up: Double) -> Double {
        let v = worldVelocity(target: target, up: up)
        guard v.x > 0.1 else { return 0 }
        return atan2(v.z, v.x) * 180 / .pi
    }

    /// World attack angle (deg, + up) from the in-plane impact velocity.
    func attackAngle(target: Double, up: Double) -> Double {
        let v = worldVelocity(target: target, up: up)
        let horizontal = sqrt(v.x * v.x + v.z * v.z)
        guard horizontal > 0.1 else { return 0 }
        return atan2(v.y, horizontal) * 180 / .pi
    }

    var deliveryDegrees: Double { deliveryDirection * 180 / .pi }
    var backswingDegrees: Double { backswingDirection * 180 / .pi }
}

extension Biomechanics.Club {
    /// Hands-to-head length (m) of this club's pendulum segment — shared by
    /// the simulation and the stage renderer so the drawn club matches the
    /// simulated one.
    var pendulumLength: Double {
        switch self {
        case .driver: return 1.13
        case .iron: return 0.94
        }
    }

    /// Swing-plane inclination above horizontal (deg).
    var planeTilt: Double {
        switch self {
        case .driver: return 54
        case .iron: return 59
        }
    }

    /// Setup bias on the horizontal swing direction (deg, + = in-to-out):
    /// the driver's forward ball position and tee invite swinging a touch
    /// more rightward through the ball.
    var swingDirectionBias: Double {
        switch self {
        case .driver: return 2.0
        case .iron: return 0.5
        }
    }
}
