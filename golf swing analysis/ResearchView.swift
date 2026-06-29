//
//  ResearchView.swift
//  golf swing analysis
//
//  Research Mode: compare two swings (A/B) with overlaid flights and a metric
//  diff, isolate a single variable while the rest stay locked, generate shot
//  dispersions, and save/load experiments.
//

import SwiftUI

struct ResearchView: View {
    @Bindable var lab: SwingLab

    @State private var swingA = SwingModel()
    @State private var swingB = SwingModel()
    @State private var seeded = false

    @State private var isolated: SwingVariable = .face

    @State private var dispersionSource = "A"
    @State private var shotCount: Int = 50
    @State private var variability: Double = 0.5
    @State private var dispersion: DispersionResult?

    @State private var experimentName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    compareSection
                    isolateSection
                    dispersionSection
                    experimentsSection
                }
                .padding()
            }
            .navigationTitle("Research")
            .onAppear {
                guard !seeded else { return }
                swingA = lab.swing
                swingB = lab.swing
                seeded = true
            }
        }
    }

    // MARK: Compare A/B

    private var compareSection: some View {
        SectionCard(title: "Compare A vs B", systemImage: "rectangle.on.rectangle") {
            HStack {
                Button("A ← Current") { swingA = lab.swing }
                Spacer()
                Button("B ← Current") { swingB = lab.swing }
                Spacer()
                Button("Send A → Sim") { lab.swing = swingA }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)

            ZStack {
                TrajectoryShape(launchDirection: 0, spinAxis: 0)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.secondary)

                TrajectoryShape(launchDirection: swingA.launchDirection, spinAxis: swingA.spinAxis)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                TrajectoryShape(launchDirection: swingB.launchDirection, spinAxis: swingB.spinAxis)
                    .stroke(.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGreen).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 12) {
                    legend(.blue, "A")
                    legend(.red, "B")
                }
                .padding(8)
            }

            diffTable
        }
    }

    private var diffTable: some View {
        VStack(spacing: 6) {
            comparisonRow("Shot", swingA.shotName, swingB.shotName, delta: nil)
            comparisonRow("Carry", fmt(swingA.carryDistance, "%.0f yd"), fmt(swingB.carryDistance, "%.0f yd"),
                          delta: swingB.carryDistance - swingA.carryDistance, unit: " yd")
            comparisonRow("Launch Dir", fmt(swingA.launchDirection, "%+.1f°"), fmt(swingB.launchDirection, "%+.1f°"),
                          delta: swingB.launchDirection - swingA.launchDirection, unit: "°")
            comparisonRow("Spin Axis", fmt(swingA.spinAxis, "%+.1f°"), fmt(swingB.spinAxis, "%+.1f°"),
                          delta: swingB.spinAxis - swingA.spinAxis, unit: "°")
            comparisonRow("Apex", fmt(swingA.peakHeight, "%.0f ft"), fmt(swingB.peakHeight, "%.0f ft"),
                          delta: swingB.peakHeight - swingA.peakHeight, unit: " ft")
            comparisonRow("Smash", fmt(swingA.smashFactor, "%.2f"), fmt(swingB.smashFactor, "%.2f"),
                          delta: swingB.smashFactor - swingA.smashFactor, unit: "")
        }
    }

    private func comparisonRow(_ label: String, _ a: String, _ b: String, delta: Double?, unit: String = "") -> some View {
        HStack {
            Text(label).font(.caption).frame(width: 80, alignment: .leading)
            Text(a).font(.caption.monospacedDigit()).foregroundStyle(.blue).frame(maxWidth: .infinity)
            Text(b).font(.caption.monospacedDigit()).foregroundStyle(.red).frame(maxWidth: .infinity)
            if let delta {
                Text(String(format: "%+.1f", delta) + unit)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            } else {
                Text("").frame(width: 64)
            }
        }
    }

    // MARK: Isolate one variable

    private var isolateSection: some View {
        SectionCard(title: "Isolate a Variable", systemImage: "lock") {
            Text("B copies A, then only the chosen variable changes — so any difference is caused by that one thing.")
                .font(.caption).foregroundStyle(.secondary)

            Picker("Variable", selection: $isolated) {
                ForEach(SwingVariable.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)

            Button("Lock B to A") { swingB = swingA }
                .buttonStyle(.bordered)
                .controlSize(.small)

            HStack {
                Text("A: \(isoText(swingA))").foregroundStyle(.blue)
                Spacer()
                Text("B: \(isoText(swingB))").foregroundStyle(.red)
            }
            .font(.caption.monospacedDigit())

            Slider(value: isolatedBinding, in: isolated.range,
                   step: isolated == .speed ? 1 : 0.5)
        }
    }

    private var isolatedBinding: Binding<Double> {
        Binding(
            get: { isolated.value(in: swingB) },
            set: { isolated.set($0, in: &swingB) }
        )
    }

    private func isoText(_ s: SwingModel) -> String {
        String(format: "%+.1f", isolated.value(in: s)) + isolated.unit
    }

    // MARK: Dispersion

    private var dispersionSection: some View {
        SectionCard(title: "Shot Dispersion", systemImage: "circle.dotted") {
            Picker("Source", selection: $dispersionSource) {
                Text("Swing A").tag("A")
                Text("Swing B").tag("B")
            }
            .pickerStyle(.segmented)

            Stepper("Shots: \(shotCount)", value: $shotCount, in: 10...200, step: 10)
                .font(.subheadline)

            VStack(spacing: 2) {
                HStack { Text("Consistency").font(.subheadline); Spacer()
                    Text(variability < 0.33 ? "Tight" : variability < 0.66 ? "Average" : "Loose")
                        .font(.subheadline).foregroundStyle(.secondary) }
                Slider(value: $variability, in: 0.05...1)
            }

            Button {
                let source = dispersionSource == "A" ? swingA : swingB
                dispersion = source.dispersion(count: shotCount, variability: variability)
            } label: {
                Label("Generate", systemImage: "dice").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            if let dispersion {
                DispersionPlot(result: dispersion)
                    .frame(height: 220)
                HStack {
                    stat("Carry", String(format: "%.0f ± %.0f yd", dispersion.meanCarry, dispersion.carryStd))
                    Spacer()
                    stat("Offline", String(format: "%+.0f ± %.0f yd", dispersion.meanOffline, dispersion.offlineStd))
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit())
        }
    }

    // MARK: Experiments

    @State private var store = ExperimentStore()

    private var experimentsSection: some View {
        SectionCard(title: "Saved Experiments", systemImage: "tray.full") {
            HStack {
                TextField("Name this experiment", text: $experimentName)
                    .textFieldStyle(.roundedBorder)
                Button("Save A") {
                    store.save(swingA, name: experimentName)
                    experimentName = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if store.experiments.isEmpty {
                Text("No saved experiments yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.experiments) { exp in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exp.name).font(.subheadline.weight(.medium))
                            Text("\(exp.swing.shotName) · \(exp.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("Load into A") { swingA = exp.swing }
                            Button("Load into B") { swingB = exp.swing }
                            Button("Load into Simulator") { lab.swing = exp.swing }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(exp) }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }

    // MARK: Helpers

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2.bold())
        }
    }

    private func fmt(_ v: Double, _ format: String) -> String { String(format: format, v) }
}

// MARK: - Section card

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Dispersion scatter plot

struct DispersionPlot: View {
    let result: DispersionResult

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Lateral bound (yards each side) and carry range.
            let maxOffline = max(15, (result.samples.map { abs($0.offline) }.max() ?? 15) + 5)
            let carries = result.samples.map(\.carry)
            let minCarry = (carries.min() ?? 0) - 5
            let maxCarry = (carries.max() ?? 1) + 5
            let carrySpan = max(maxCarry - minCarry, 1)

            let toPoint: (ShotSample) -> CGPoint = { s in
                let x = w / 2 + CGFloat(s.offline / maxOffline) * (w / 2 - 12)
                let y = h - 12 - CGFloat((s.carry - minCarry) / carrySpan) * (h - 40)
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // Target center line.
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 8))
                    p.addLine(to: CGPoint(x: w / 2, y: h - 8))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(.secondary)

                ForEach(result.samples) { sample in
                    Circle()
                        .fill(.orange.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .position(toPoint(sample))
                }

                // Mean marker.
                Circle()
                    .strokeBorder(.blue, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .position(toPoint(ShotSample(offline: result.meanOffline, carry: result.meanCarry)))

                Text("± \(Int(maxOffline)) yd")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
            }
        }
        .background(Color(.systemGreen).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
