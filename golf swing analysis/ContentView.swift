//
//  ContentView.swift
//  golf swing analysis
//
//  Created by Ralph Halabi on 6/27/26.
//

import SwiftUI

/// Tab container and owner of the shared `SwingLab` state.
struct RootView: View {
    @State private var lab = SwingLab()

    var body: some View {
        TabView {
            ContentView(lab: lab)
                .tabItem { Label("Impact", systemImage: "scope") }
            BiomechanicsView(lab: lab)
                .tabItem { Label("Body", systemImage: "figure.golf") }
            LearnView(lab: lab)
                .tabItem { Label("Learn", systemImage: "graduationcap") }
            ResearchView(lab: lab)
                .tabItem { Label("Research", systemImage: "flask") }
        }
    }
}

struct ContentView: View {
    @Bindable var lab: SwingLab
    @State private var perspective: Perspective = .top

    private var swing: SwingModel { lab.swing }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                Picker("Perspective", selection: $perspective) {
                    ForEach(Perspective.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                perspectiveView
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(skyGround)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(perspective.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statBar
                controls
                lessonPicker
                coachingCard
            }
            .padding()
        }
    }

    private var header: some View {
        Text(swing.shotName)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var perspectiveView: some View {
        switch perspective {
        case .front: FrontFlightView(swing: swing)
        case .top: RangeView(swing: swing)
        case .downLine: DownLineFlightView(swing: swing)
        case .face: ClubFaceView(swing: swing, leftHanded: $lab.leftHanded)
        }
    }

    private var skyGround: some View {
        LinearGradient(colors: [Color(.systemBlue).opacity(0.10), Color(.systemGreen).opacity(0.14)],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: Simple stats

    private var statBar: some View {
        HStack(spacing: 0) {
            stat("Carry", "\(Int(swing.carryDistance)) yd")
            Divider().frame(height: 32)
            stat("Start", startText)
            Divider().frame(height: 32)
            stat("Curve", curveText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var startText: String {
        let d = swing.launchDirection
        if abs(d) < 1 { return "On line" }
        return String(format: "%.0f° %@", abs(d), d > 0 ? "R" : "L")
    }

    private var curveText: String {
        let curve = (swing.spinAxis / 45) * max(swing.carryDistance, 1) * 0.5
        if abs(curve) < 1 { return "Straight" }
        return String(format: "%.0f yd %@", abs(curve), curve > 0 ? "R" : "L")
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            ParameterSlider(title: "Club Face", value: $lab.swing.faceAngle,
                            range: -10...10, unit: "°", lowLabel: "Closed", highLabel: "Open")
            ParameterSlider(title: "Club Path", value: $lab.swing.clubPath,
                            range: -10...10, unit: "°", lowLabel: "Out-to-in", highLabel: "In-to-out")

            Button {
                withAnimation { lab.swing.faceAngle = 0; lab.swing.clubPath = 0 }
            } label: {
                Label("Reset Sliders", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: Lessons & coaching

    private var lessonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try a shot").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Lesson.library) { lesson in
                        Button {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                lab.swing.faceAngle = lesson.faceAngle
                                lab.swing.clubPath = lesson.clubPath
                            }
                        } label: {
                            Text(lesson.title)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.tint.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why this happens", systemImage: "lightbulb")
                .font(.headline)
            Text(swing.ballFlight.startExplanation)
            Text(swing.ballFlight.curveExplanation)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Reusable slider

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = ""
    var lowLabel: String = ""
    var highLabel: String = ""
    var caption: String? = nil
    var step: Double = 0.5

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%+.1f", value) + unit)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
            HStack {
                Text(lowLabel)
                Spacer()
                if let caption { Text(caption).italic() }
                Spacer()
                Text(highLabel)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Top-down range / ball flight

struct RangeView: View {
    let swing: SwingModel

    var body: some View {
        GeometryReader { geo in
            let g = RangeGeometry(swing: swing, size: geo.size)

            ZStack {
                yardGrid(g)

                // Target line (straight to the pin).
                line(from: g.point(distance: 0, lateral: 0), to: g.point(distance: g.maxYards, lateral: 0))
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .foregroundStyle(.secondary)

                // Pin at the target.
                pin(at: g.point(distance: g.maxYards * 0.96, lateral: 0))

                // Start line: where the face aimed, no curve.
                startLine(g)
                    .stroke(.blue.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

                // Actual curved ball flight.
                ballPath(g)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Landing marker + label.
                landingMarker(g)

                // Tee.
                Circle().fill(.white).stroke(.orange, lineWidth: 2)
                    .frame(width: 11, height: 11)
                    .position(g.point(distance: 0, lateral: 0))

                legend
            }
        }
    }

    // MARK: Pieces

    private func yardGrid(_ g: RangeGeometry) -> some View {
        ForEach(g.yardMarks, id: \.self) { yards in
            let y = g.point(distance: yards, lateral: 0).y
            ZStack(alignment: .leading) {
                Path { p in
                    p.move(to: CGPoint(x: 8, y: y))
                    p.addLine(to: CGPoint(x: g.size.width - 8, y: y))
                }
                .stroke(.secondary.opacity(0.12), lineWidth: 1)

                Text("\(Int(yards))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary.opacity(0.6))
                    .position(x: 18, y: y - 7)
            }
        }
    }

    private func startLine(_ g: RangeGeometry) -> Path {
        Path { p in
            p.move(to: g.point(distance: 0, lateral: 0))
            let end = min(g.carry, g.maxYards)
            p.addLine(to: g.point(distance: end, lateral: g.startLateral(at: end)))
        }
    }

    private func ballPath(_ g: RangeGeometry) -> Path {
        Path { p in
            p.move(to: g.point(distance: 0, lateral: 0))
            let steps = 60
            for i in 1...steps {
                let d = g.carry * Double(i) / Double(steps)
                p.addLine(to: g.point(distance: d, lateral: g.lateral(at: d)))
            }
        }
    }

    private func landingMarker(_ g: RangeGeometry) -> some View {
        let pt = g.point(distance: g.carry, lateral: g.lateral(at: g.carry))
        return ZStack {
            Circle().fill(.orange).frame(width: 10, height: 10).position(pt)
            Text("\(Int(g.carry)) yd · \(offlineLabel(g.offline))")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .position(x: pt.x, y: pt.y - 14)
        }
    }

    private func pin(at pt: CGPoint) -> some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 12))
            .foregroundStyle(.red)
            .position(x: pt.x + 6, y: pt.y - 6)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow(.blue, "Start line (face)")
            legendRow(.orange, "Ball flight")
        }
        .padding(7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(8)
    }

    private func legendRow(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 12, height: 3)
            Text(text).font(.system(size: 9))
        }
    }

    private func line(from a: CGPoint, to b: CGPoint) -> Path {
        Path { p in p.move(to: a); p.addLine(to: b) }
    }

    private func offlineLabel(_ offline: Double) -> String {
        if abs(offline) < 1 { return "on line" }
        return String(format: "%.0f yd %@", abs(offline), offline > 0 ? "R" : "L")
    }
}

/// Maps real yards (downrange and lateral) onto the view, scaled to the shot.
private struct RangeGeometry {
    let swing: SwingModel
    let size: CGSize

    var carry: Double { max(swing.carryDistance, 1) }
    var offline: Double { swing.landingOffline }

    /// Top of the range, rounded up to a tidy number above the carry.
    var maxYards: Double {
        let target = carry * 1.12
        return (target / 50).rounded(.up) * 50
    }

    var yardMarks: [Double] {
        stride(from: 50, through: maxYards, by: 50).map { $0 }
    }

    /// Lateral span (yards) that fills half the width, with headroom for the curve.
    private var maxLateral: Double {
        max(35, abs(offline) * 1.4)
    }

    private var teeY: CGFloat { size.height - 18 }
    private var topY: CGFloat { 14 }
    private var teeX: CGFloat { size.width / 2 }

    func point(distance d: Double, lateral: Double) -> CGPoint {
        let up = CGFloat(d / maxYards) * (teeY - topY)
        let xScale = (size.width / 2 - 16) / CGFloat(maxLateral)
        return CGPoint(x: teeX + CGFloat(lateral) * xScale, y: teeY - up)
    }

    /// Straight start line (face aim), no curvature.
    func startLateral(at d: Double) -> Double {
        tan(swing.launchDirection * .pi / 180) * d
    }

    /// Actual lateral offset including the spin-axis curve, in yards.
    func lateral(at d: Double) -> Double {
        let start = tan(swing.launchDirection * .pi / 180) * d
        let curve = (swing.spinAxis / 45) * carry * 0.5 * pow(d / carry, 2)
        return start + curve
    }
}

#Preview {
    RootView()
}
