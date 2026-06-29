//
//  SwingLab.swift
//  golf swing analysis
//
//  Shared app state. Holding the swing and the body in one observable object
//  keeps the cause-and-effect chain connected: changes on the Body tab can be
//  pushed into the Impact simulator, which feeds the ball-flight engine.
//

import Observation

@Observable
final class SwingLab {
    var swing = SwingModel()
    var biomechanics = Biomechanics()
    var leftHanded = false

    /// Push the current body-derived delivery into the impact simulator.
    func sendBodyToImpact() {
        biomechanics.apply(to: &swing)
    }
}
