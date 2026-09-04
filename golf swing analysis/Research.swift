//
//  Research.swift
//  golf swing analysis
//
//  The Research Mode engine: an editable list of swing variables (for isolating
//  one at a time), a Monte-Carlo shot-dispersion generator, a reusable top-down
//  trajectory shape for overlays, and a persisted store of saved experiments.
//

import Foundation
import Observation
import SwiftUI

// MARK: - Selectable swing variables (for "change one, lock the rest")

enum SwingVariable: String, CaseIterable, Identifiable {
    case face = "Club Face"
    case path = "Club Path"
    case attack = "Angle of Attack"
    case loft = "Dynamic Loft"
    case strike = "Strike"
    case speed = "Swing Speed"

    var id: String { rawValue }

    func value(in s: SwingModel) -> Double {
        switch self {
        case .face: return s.faceAngle
        case .path: return s.clubPath
        case .attack: return s.angleOfAttack
        case .loft: return s.dynamicLoft
        case .strike: return s.strikeOffset
        case .speed: return s.swingSpeed
        }
    }

    func set(_ value: Double, in s: inout SwingModel) {
        switch self {
        case .face: s.faceAngle = value
        case .path: s.clubPath = value
        case .attack: s.angleOfAttack = value
        case .loft: s.dynamicLoft = value
        case .strike: s.strikeOffset = value
        case .speed: s.swingSpeed = value
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .face, .path: return -10...10
        case .attack: return -8...8
        case .loft: return 5...35
        case .strike: return -25...25
        case .speed: return 60...130
        }
    }

    var unit: String { self == .strike ? " mm" : self == .speed ? " mph" : "°" }
}

// MARK: - Shot dispersion (Monte-Carlo)

struct ShotSample: Identifiable {
    let id = UUID()
    let offline: Double   // yards right(+)/left(-) of target at landing
    let carry: Double     // yards
}

struct DispersionResult {
    var samples: [ShotSample]
    var meanCarry: Double
    var carryStd: Double
    var meanOffline: Double
    var offlineStd: Double
}

extension SwingModel {

    /// Landing position relative to target: start direction carried downrange,
    /// plus the sideways push from spin-axis curve.
    var landingOffline: Double {
        let start = tan(launchDirection * .pi / 180) * carryDistance
        let curve = (spinAxis / 45) * carryDistance * 0.5
        return start + curve
    }

    /// Simulates `count` shots, jittering the player's delivery by `variability`
    /// (0 = robot, 1 = very loose), and returns the landing scatter with stats.
    func dispersion(count: Int, variability: Double) -> DispersionResult {
        func gauss() -> Double {
            let u1 = Double.random(in: 1e-9...1)
            let u2 = Double.random(in: 0...1)
            return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
        }

        var samples: [ShotSample] = []
        for _ in 0..<count {
            var s = self
            s.faceAngle += gauss() * 1.5 * variability
            s.clubPath += gauss() * 1.5 * variability
            s.angleOfAttack += gauss() * 1.0 * variability
            s.strikeOffset += gauss() * 6.0 * variability
            s.swingSpeed += gauss() * 3.0 * variability
            samples.append(ShotSample(offline: s.landingOffline, carry: s.carryDistance))
        }

        let n = Double(max(count, 1))
        let carries = samples.map(\.carry)
        let offlines = samples.map(\.offline)
        let meanCarry = carries.reduce(0, +) / n
        let meanOffline = offlines.reduce(0, +) / n
        let carryStd = (carries.map { pow($0 - meanCarry, 2) }.reduce(0, +) / n).squareRoot()
        let offlineStd = (offlines.map { pow($0 - meanOffline, 2) }.reduce(0, +) / n).squareRoot()

        return DispersionResult(samples: samples, meanCarry: meanCarry, carryStd: carryStd,
                                meanOffline: meanOffline, offlineStd: offlineStd)
    }
}

// MARK: - Standard-deviation dispersion ellipse

/// A dispersion ellipse in **(offline, carry) yard-space**: `center` in yards,
/// `semiMajor` / `semiMinor` in yards along the cloud's principal axes, and
/// `rotation` the angle of the major axis measured from the +offline axis toward
/// +carry. Convert to screen points at draw time (the top-down view scales
/// offline and carry by different factors, so the ellipse must be re-fitted in
/// screen space rather than scaled naively).
///
/// **This is a standard-deviation-multiple ellipse, not a χ² confidence region.**
/// It is the principal-axis ellipse of the sample covariance with half-axes
/// `k · √λ` (λ = covariance eigenvalues). Read along any single axis those
/// half-axes are exactly ±1σ (k = 1) and ±2σ (k = 2), which is why they're
/// labelled with the familiar 1-D "68%" / "95%". But the *area* of the k = 1
/// ellipse holds only ≈ 1 − e^(−1/2) ≈ 39% of a bivariate-normal cloud, and the
/// k = 2 ellipse ≈ 1 − e^(−2) ≈ 86%. A true 2-D 68% / 95% region would inflate
/// the axes by √χ²₂,p (≈ 1.52 and ≈ 2.45). We deliberately draw the plain
/// k = 1 / k = 2 ellipse because the study frames this as "one and two standard
/// deviations of shot scatter"; the χ² distinction is noted here so the shaded
/// area isn't misread as a probability contour.
struct DispersionEllipse {
    var centerOffline: Double
    var centerCarry: Double
    var semiMajor: Double
    var semiMinor: Double
    var rotation: Angle
}

extension DispersionResult {

    /// The k = 1 and k = 2 standard-deviation ellipses for this shot cloud in
    /// yard-space, or `nil` when the cloud is too small (< 3 shots) or too tight
    /// (essentially a deterministic swing) to fit a non-degenerate ellipse.
    /// See `DispersionEllipse` for what "σ ellipse" means here — it is an
    /// SD-multiple approximation, not a chi-square confidence region.
    var sigmaEllipses: (oneSigma: DispersionEllipse, twoSigma: DispersionEllipse)? {
        guard samples.count >= 3 else { return nil }
        let n = Double(samples.count)
        let mo = samples.reduce(0) { $0 + $1.offline } / n
        let mc = samples.reduce(0) { $0 + $1.carry } / n

        var vxx = 0.0, vyy = 0.0, vxy = 0.0   // covariance of (offline, carry)
        for s in samples {
            let dx = s.offline - mo
            let dy = s.carry - mc
            vxx += dx * dx
            vyy += dy * dy
            vxy += dx * dy
        }
        vxx /= n; vyy /= n; vxy /= n

        // Eigen-decomposition of the symmetric 2×2 covariance [[vxx, vxy],[vxy, vyy]].
        let trace = vxx + vyy
        let det = vxx * vyy - vxy * vxy
        let disc = max(0, trace * trace / 4 - det)
        let root = disc.squareRoot()
        let lambdaMajor = trace / 2 + root
        let lambdaMinor = trace / 2 - root

        // Degenerate: variance under ~0.1 yd along the major axis → no ellipse.
        guard lambdaMajor.isFinite, lambdaMajor > 0.01 else { return nil }

        let a = lambdaMajor.squareRoot()
        let b = max(lambdaMinor, 0).squareRoot()
        let angle = abs(vxy) > 1e-12
            ? atan2(lambdaMajor - vxx, vxy)
            : (vxx >= vyy ? 0 : Double.pi / 2)

        func ellipse(k: Double) -> DispersionEllipse {
            DispersionEllipse(centerOffline: mo,
                              centerCarry: mc,
                              semiMajor: k * a,
                              semiMinor: k * max(b, a * 0.02),   // keep a sliver of width if collinear
                              rotation: .radians(angle))
        }
        return (ellipse(k: 1), ellipse(k: 2))
    }
}

// MARK: - Reusable top-down trajectory (for A/B overlay)

struct TrajectoryShape: Shape {
    var launchDirection: Double
    var spinAxis: Double

    func path(in rect: CGRect) -> Path {
        let teeX = rect.midX
        let teeY = rect.maxY
        let length = rect.height
        let startSlope = tan(launchDirection * .pi / 180)
        let curveScale = CGFloat(spinAxis / 45) * rect.width * 0.5

        var p = Path()
        p.move(to: CGPoint(x: teeX, y: teeY))
        let steps = 60
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let up = length * t
            let lateral = startSlope * up + curveScale * t * t
            p.addLine(to: CGPoint(x: teeX + lateral, y: teeY - up))
        }
        return p
    }
}

// MARK: - Saved experiments (persisted)

struct Experiment: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    var swing: SwingModel
}

@Observable
final class ExperimentStore {
    private(set) var experiments: [Experiment] = []
    private let storageKey = "savedExperiments"

    init() { load() }

    func save(_ swing: SwingModel, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty ? "Experiment \(experiments.count + 1)" : trimmed
        experiments.insert(Experiment(name: finalName, date: .now, swing: swing), at: 0)
        persist()
    }

    func delete(_ experiment: Experiment) {
        experiments.removeAll { $0.id == experiment.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(experiments) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Experiment].self, from: data) else { return }
        experiments = decoded
    }
}
