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
