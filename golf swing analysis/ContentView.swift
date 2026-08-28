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
        @Bindable var lab = lab
        TabView(selection: $lab.selectedTab) {
            ContentView(lab: lab)
                .tabItem { Label("Shot Lab", systemImage: "scope") }
                .tag(AppTab.impact)
            BiomechanicsView(lab: lab)
                .tabItem { Label("Swing Lab", systemImage: "figure.golf") }
                .tag(AppTab.body)
            LearnView(lab: lab)
                .tabItem { Label("Lessons", systemImage: "graduationcap") }
                .tag(AppTab.learn)
            ResearchView(lab: lab)
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.research)
        }
    }
}

struct ContentView: View {
    private enum ControlAnchor: Hashable { case face, path, contact, attack, loft, speed }

    @Bindable var lab: SwingLab
    var configuration: ShotLabConfiguration = .explore
    @State private var perspective: Perspective = .top
    @State private var modelExpanded = false
    @State private var presetsExpanded = false
    @State private var previousShotName: String?
    @State private var changeTask: Task<Void, Never>?
    @State private var variablesExpanded = false

    private var swing: SwingModel { lab.swing }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.gap) {
                        shotHeader
                        shotVisualizer
                        primaryControls
                        deliveryAndContact
                        resultingLaunch
                        whyThisFlightCard
                        variablesReference { anchor in
                            withAnimation(.easeInOut) { proxy.scrollTo(anchor, anchor: .top) }
                        }
                        CardSection("Flight Patterns", systemImage: "target") {
                            DisclosureGroup(isExpanded: $presetsExpanded) {
                                lessonScroll
                                    .padding(.top, 8)
                            } label: {
                                Text("Explore common starts, curves, and misses")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Shot Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            lab.swing = SwingModel()
                        }
                    } label: {
                        Label("Reset Shot", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .onChange(of: swing.shotName) { oldName, newName in
                guard oldName != newName else { return }
                previousShotName = oldName
                changeTask?.cancel()
                changeTask = Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { previousShotName = nil }
                }
            }
        }
    }

    private var shotVisualizer: some View {
        VStack(spacing: Theme.innerGap) {
            perspectiveView.fieldPanel(height: 245)

            Picker("Perspective", selection: $perspective) {
                ForEach(Perspective.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var shotHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BALL FLIGHT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(swing.shotName)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer()
                shotBadge
            }

            Text(swing.flightClassification.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let previousShotName {
                Text("What changed?  \(previousShotName) → \(swing.shotName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                shotMetric("START", startText, Theme.path)
                shotMetric("CURVE", curveText, Theme.face)
                shotMetric("FINISH", offlineText, severityColor)
            }
            .animation(.easeInOut(duration: 0.2), value: swing.shotName)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private var shotBadge: some View {
        Label(severityLabel, systemImage: severityIcon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(severityColor.opacity(0.15), in: Capsule())
            .foregroundStyle(severityColor)
    }

    private func shotMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private var impactModelCard: some View {
        CardSection("Impact Model", systemImage: "function") {
            DisclosureGroup(isExpanded: $modelExpanded) {
                VStack(spacing: 10) {
                    modelRow("1", "Face controls start", swing.ballFlight.startExplanation)
                    modelRow("2", "Face-to-path controls curve", swing.ballFlight.curveExplanation)
                    modelRow("3", "Launch conditions set carry", String(format: "%.1f° launch, %.0f ft apex, %.0f rpm spin", swing.launchAngle, swing.peakHeight, swing.backSpin))
                }
                .padding(.top, 8)
            } label: {
                Text(modelSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func modelRow(_ index: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Theme.inset, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whyThisFlightCard: some View {
        CardSection("Why This Flight", systemImage: "lightbulb") {
            VStack(alignment: .leading, spacing: 12) {
                explanationBlock("START", startExplanation)
                explanationBlock("CURVE", curveExplanation)
                explanationBlock("LAUNCH", "Dynamic loft, angle of attack, centeredness of contact, and club speed produced the current launch, spin, height, and carry.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func explanationBlock(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private func explanationMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var perspectiveView: some View {
        switch perspective {
        case .top: RangeView(swing: swing)
        case .downLine: DownLineFlightView(swing: swing)
        case .side: SideTrajectoryView(swing: swing)
        case .face: ClubFaceView(swing: swing, leftHanded: $lab.leftHanded)
        }
    }

    // MARK: Shot copy

    private var shotDescription: String {
        "Starts \(startDirectionWord), curves \(curveDirectionWord), and finishes \(finishDirectionWord)."
    }

    private var startExplanation: String {
        switch swing.flightClassification.startDirection {
        case .straight: return "The ball starts on line because the face is delivered close to the target at impact."
        case .left: return "The ball starts left because the face is pointed left of the target at impact."
        case .right: return "The ball starts right because the face is pointed right of the target at impact."
        }
    }

    private var curveExplanation: String {
        switch swing.flightClassification.curveDirection {
        case .straight: return "The club face angle and club path were closely matched, producing little horizontal curvature."
        case .left: return "The face was closed relative to the club path, producing leftward curvature."
        case .right: return "The face was open relative to the club path, producing rightward curvature."
        }
    }

    private var coachLead: String {
        if abs(swing.faceToPath) < 1 {
            return "Face and path are matched, so this shot is mostly about start direction."
        }
        let relationship = swing.faceToPath > 0 ? "open" : "closed"
        return "The face is \(relationship) to the path by \(String(format: "%.1f", abs(swing.faceToPath)))°, which is the main curve source."
    }

    private var modelSummary: String {
        String(format: "Face-to-path %+.1f° | launch %.1f° | spin %.0f rpm", swing.faceToPath, swing.launchAngle, swing.backSpin)
    }

    private var startDirectionWord: String {
        let d = swing.launchDirection
        if abs(d) < 1 { return "on line" }
        return d > 0 ? "right" : "left"
    }

    private var curveDirectionWord: String {
        let curve = estimatedCurve
        if abs(curve) < 1 { return "barely at all" }
        return curve > 0 ? "right" : "left"
    }

    private var finishDirectionWord: String {
        let finish = swing.landingOffline
        if abs(finish) < 1 { return "near the target" }
        return finish > 0 ? "right of target" : "left of target"
    }

    private var estimatedCurve: Double {
        (swing.spinAxis / 45) * max(swing.carryDistance, 1) * 0.5
    }

    private var targetHalfWidth: Double { 10 }

    private var severityLabel: String {
        switch abs(swing.landingOffline) {
        case ...targetHalfWidth: return "In Window"
        case ...(targetHalfWidth * 2): return "Playable Miss"
        default: return "Big Miss"
        }
    }

    private var severityIcon: String {
        switch abs(swing.landingOffline) {
        case ...targetHalfWidth: return "checkmark.circle.fill"
        case ...(targetHalfWidth * 2): return "exclamationmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var severityColor: Color {
        switch abs(swing.landingOffline) {
        case ...targetHalfWidth: return Theme.good
        case ...(targetHalfWidth * 2): return Theme.warn
        default: return Theme.bad
        }
    }

    private var faceToPathColor: Color {
        abs(swing.faceToPath) < 1 ? Theme.good : Theme.face
    }

    private var offlineText: String {
        if abs(swing.landingOffline) < 1 { return "0 yd" }
        return String(format: "%.0f yd %@", abs(swing.landingOffline), swing.landingOffline > 0 ? "R" : "L")
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

    private var primaryControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("IMPACT DIRECTION", systemImage: "arrow.down.right.and.arrow.up.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ParameterSlider(title: "Club Face", value: $lab.swing.faceAngle,
                            range: -10...10, unit: "°", lowLabel: "Closed", highLabel: "Open",
                            caption: "Square",
                            info: "Club face is where the face points at impact. It has the biggest influence on where the ball starts: open points it right, closed points it left.")
                .id(ControlAnchor.face)
            ParameterSlider(title: "Club Path", value: $lab.swing.clubPath,
                            range: -10...10, unit: "°", lowLabel: "Out-to-in", highLabel: "In-to-out",
                            caption: "Neutral",
                            info: "Club path is the direction the clubhead travels through impact. The difference between face and path creates curve: face open to path curves the ball right, while face closed to path curves it left.")
                .id(ControlAnchor.path)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FACE TO PATH").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Primary curve influence").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%+.1f°", swing.faceToPath)).font(.headline.monospacedDigit())
                    Text(faceToPathRelationship).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private var faceToPathRelationship: String {
        if abs(swing.faceToPath) < 1 { return "Matched to path" }
        return swing.faceToPath > 0 ? "Open relative to path" : "Closed relative to path"
    }

    private var deliveryAndContact: some View {
        CardSection("Delivery & Contact", systemImage: "scope") {
            VStack(spacing: 12) {
                ContactLocationControl(
                    strikeX: $lab.swing.strikeOffset,
                    strikeY: $lab.swing.strikeHeightOffset
                )
                .id(ControlAnchor.contact)

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    ParameterSlider(title: "Angle of Attack", value: $lab.swing.angleOfAttack,
                                    range: -8...8, unit: "°", lowLabel: "Down", highLabel: "Up",
                                    info: "The vertical direction the clubhead is moving at impact.")
                    Text(attackDescription).font(.caption).foregroundStyle(.secondary)
                }
                .id(ControlAnchor.attack)

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    ParameterSlider(title: "Dynamic Loft", value: $lab.swing.dynamicLoft,
                                    range: 6...24, unit: "°", lowLabel: "Low", highLabel: "High",
                                    info: "The loft delivered by the club at impact.")
                    Text("Loft delivered at impact.").font(.caption).foregroundStyle(.secondary)
                    Text("Influences launch · spin · height").font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                }
                .id(ControlAnchor.loft)

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    ParameterSlider(title: "Club Speed", value: $lab.swing.swingSpeed,
                                    range: 70...120, unit: " mph", lowLabel: "Slow", highLabel: "Fast", step: 1,
                                    info: "The speed of the clubhead at impact.")
                    Text("Influences potential ball speed and distance.").font(.caption).foregroundStyle(.secondary)
                }
                .id(ControlAnchor.speed)
            }
        }
    }

    private var attackDescription: String {
        if swing.angleOfAttack < -0.5 { return "Clubhead moving downward at impact." }
        if swing.angleOfAttack > 0.5 { return "Clubhead moving upward at impact." }
        return "Clubhead moving approximately level at impact."
    }

    private var resultingLaunch: some View {
        CardSection("Resulting Launch", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    sideMetric("Launch", String(format: "%.1f°", swing.launchAngle), .blue)
                    sideMetric("Apex", "\(Int(swing.peakHeight)) ft", apexPreviewColor)
                    sideMetric("Carry", "\(Int(swing.carryDistance)) yd", .green)
                }
                HStack {
                    Text("Backspin")
                    Spacer()
                    Text("\(Int(swing.backSpin).formatted()) rpm").monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var launchPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sideMetric("Launch", String(format: "%.1f°", swing.launchAngle), .blue)
                sideMetric("Apex", "\(Int(swing.peakHeight)) ft", apexPreviewColor)
                sideMetric("Carry", "\(Int(swing.carryDistance)) yd", .green)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(apexPreviewLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(apexPreviewColor)
                    Spacer()
                    Text("Backspin \(Int(swing.backSpin)) rpm")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    let x = apexMarkerX(width: geo.size.width)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        HStack(spacing: 0) {
                            Rectangle().fill(.blue.opacity(0.35))
                            Rectangle().fill(.orange.opacity(0.35))
                            Rectangle().fill(.purple.opacity(0.35))
                        }
                        .clipShape(Capsule())
                        Capsule()
                            .fill(apexPreviewColor)
                            .frame(width: 4)
                            .offset(x: x)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("Low")
                    Spacer()
                    Text("Stock")
                    Spacer()
                    Text("High")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func sideMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var apexPreviewLabel: String {
        switch swing.peakHeight {
        case ..<65: return "Low Apex"
        case 105...: return "High Apex"
        default: return "Stock Apex"
        }
    }

    private var apexPreviewColor: Color {
        switch swing.peakHeight {
        case ..<65: return .blue
        case 105...: return .purple
        default: return .orange
        }
    }

    private func apexMarkerX(width: CGFloat) -> CGFloat {
        let normalized = (swing.peakHeight - 40) / 100
        let clamped = min(max(normalized, 0), 1)
        return max(0, width - 4) * CGFloat(clamped)
    }

    private func variablesReference(onSelect: @escaping (ControlAnchor) -> Void) -> some View {
        CardSection("Ball Flight Variables", systemImage: "square.grid.2x3") {
            VStack(alignment: .leading, spacing: 10) {
                Text("The six impact variables used in this model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    variableButton("Face", anchor: .face, onSelect: onSelect)
                    variableButton("Path", anchor: .path, onSelect: onSelect)
                    variableButton("Contact", anchor: .contact, onSelect: onSelect)
                    variableButton("Attack", anchor: .attack, onSelect: onSelect)
                    variableButton("Loft", anchor: .loft, onSelect: onSelect)
                    variableButton("Speed", anchor: .speed, onSelect: onSelect)
                }

                DisclosureGroup("About the six variables", isExpanded: $variablesExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([ControlAnchor.face, .path, .contact, .attack, .loft, .speed], id: \.self) { anchor in
                            Text(variableDescription(anchor))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                }
                .font(.caption.weight(.medium))
            }
        }
    }

    private func variableButton(_ title: String, anchor: ControlAnchor, onSelect: @escaping (ControlAnchor) -> Void) -> some View {
        Button {
            onSelect(anchor)
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
        }
        .buttonStyle(.plain)
        .accessibilityHint(variableDescription(anchor))
    }

    private func variableDescription(_ anchor: ControlAnchor) -> String {
        switch anchor {
        case .face: return "Club Face Angle — Where the club face is pointed horizontally at impact."
        case .path: return "Club Path — The horizontal direction the clubhead is moving at impact."
        case .contact: return "Centeredness of Contact — Where the ball contacts the club face."
        case .attack: return "Angle of Attack — The vertical direction the clubhead is moving at impact."
        case .loft: return "Dynamic Loft — The loft delivered by the club at impact."
        case .speed: return "Club Speed — The speed of the clubhead at impact."
        }
    }

    private var lessonScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Lesson.library) { lesson in
                    Button {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            lab.swing.faceAngle = lesson.faceAngle
                            lab.swing.clubPath = lesson.clubPath
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(.subheadline.weight(.semibold))
                            Text(lesson.coaching)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(width: 170, height: 78, alignment: .topLeading)
                        .padding(12)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.insetRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Two-axis contact control

struct ContactLocationControl: View {
    @Binding var strikeX: Double
    @Binding var strikeY: Double

    private let xRange = 20.0
    private let yRange = 15.0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Centeredness of Contact").font(.subheadline.weight(.medium))
                Spacer()
                Button("Center") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        strikeX = 0
                        strikeY = 0
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            GeometryReader { geo in
                let inset: CGFloat = 22
                let width = max(1, geo.size.width - inset * 2)
                let height = max(1, geo.size.height - inset * 2)
                let marker = CGPoint(
                    x: inset + width * CGFloat((strikeX / xRange + 1) / 2),
                    y: inset + height * CGFloat((1 - strikeY / yRange) / 2)
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.inset)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.secondary.opacity(0.22), lineWidth: 1)
                        }
                        .padding(.horizontal, inset)
                        .padding(.vertical, inset)

                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width / 2, y: inset))
                        path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height - inset))
                        path.move(to: CGPoint(x: inset, y: geo.size.height / 2))
                        path.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height / 2))
                    }
                    .stroke(.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Text("High").position(x: geo.size.width / 2, y: 8)
                    Text("Low").position(x: geo.size.width / 2, y: geo.size.height - 8)
                    Text("Heel").position(x: 14, y: geo.size.height / 2)
                    Text("Toe").position(x: geo.size.width - 12, y: geo.size.height / 2)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .position(marker)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let normalizedX = min(1, max(-1, Double((value.location.x - inset) / width) * 2 - 1))
                            let normalizedY = min(1, max(-1, 1 - Double((value.location.y - inset) / height) * 2))
                            strikeX = normalizedX * xRange
                            strikeY = normalizedY * yRange
                        }
                )
            }
            .frame(height: 128)

            Text(contactDescription)
                .font(.caption.weight(.medium))
                .foregroundStyle(isCentered ? Theme.good : .secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Centeredness of Contact")
        .accessibilityValue(contactDescription)
    }

    private var isCentered: Bool { abs(strikeX) < 3 && abs(strikeY) < 3 }

    private var contactDescription: String {
        if isCentered { return "Centered contact" }

        let horizontal = strikeX < -3 ? "heel" : strikeX > 3 ? "toe" : ""
        let vertical = strikeY < -3 ? "Low" : strikeY > 3 ? "High" : ""
        if vertical.isEmpty { return "\(horizontal.capitalized) contact" }
        if horizontal.isEmpty { return "\(vertical) contact" }
        return "\(vertical)-\(horizontal) contact"
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
    var info: String? = nil
    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(title).font(.subheadline.weight(.medium))
                if info != nil {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About \(title)")
                }
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
        .alert(title, isPresented: $showingInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            if let info {
                Text(info)
            }
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
                rangeBase(g)
                roughTexture(g)
                fairway(g)
                green(g)
                yardGrid(g)
                targetWindow(g)

                line(from: g.point(distance: 0, lateral: 0), to: g.point(distance: g.maxYards, lateral: 0))
                    .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))

                pin(at: g.point(distance: g.targetDistance, lateral: 0))

                startLine(g)
                    .stroke(Theme.path.opacity(0.86), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [4, 5]))

                ballPath(g)
                    .stroke(Theme.face.opacity(0.26), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

                ballPath(g)
                    .stroke(Theme.face, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                flightDots(g)

                landingMarker(g)

                teeMarker(g)

                resultPill(g)
                legend
            }
        }
    }

    // MARK: Pieces

    private func rangeBase(_ g: RangeGeometry) -> some View {
        ZStack {
            LinearGradient(
                colors: [Scenery.turfDeep, Scenery.turfMid, Scenery.turfDeep],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach([-30.0, -15.0, 15.0, 30.0], id: \.self) { lateral in
                line(from: g.point(distance: 0, lateral: lateral), to: g.point(distance: g.maxYards, lateral: lateral))
                    .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
            }

            GrassTexture(bladeCount: 70, tint: .white.opacity(0.05))
        }
    }

    private func roughTexture(_ g: RangeGeometry) -> some View {
        ZStack {
            ForEach(0..<44, id: \.self) { index in
                let x = Scenery.noise(index, seed: 41) * g.size.width
                let y = Scenery.noise(index, seed: 73) * g.size.height
                let width = 28 + 42 * Scenery.noise(index, seed: 89)
                let height = 10 + 20 * Scenery.noise(index, seed: 97)

                Ellipse()
                    .fill(Scenery.turfDeep.opacity(0.10 + 0.08 * Scenery.noise(index, seed: 109)))
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(Scenery.noise(index, seed: 113) * 180))
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func fairway(_ g: RangeGeometry) -> some View {
        let outline = fairwayOutline(g)
        return ZStack {
            outline.fill(
                LinearGradient(
                    colors: [Scenery.fairway, Scenery.fairwayLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            mowStripes(g)
                .fill(.white.opacity(0.06))
                .clipShape(FixedPathShape(fixed: outline))
        }
    }

    private func fairwayOutline(_ g: RangeGeometry) -> Path {
        Path { path in
            let steps = 18
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let distance = g.maxYards * t
                let width = g.fairwayHalfWidth(at: distance)
                let point = g.point(distance: distance, lateral: width)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            for i in stride(from: steps, through: 0, by: -1) {
                let t = Double(i) / Double(steps)
                let distance = g.maxYards * t
                let width = g.fairwayHalfWidth(at: distance)
                path.addLine(to: g.point(distance: distance, lateral: -width))
            }

            path.closeSubpath()
        }
    }

    /// Alternating 25-yard mow bands, clipped to the fairway outline.
    private func mowStripes(_ g: RangeGeometry) -> Path {
        Path { p in
            var d = 0.0
            while d < g.maxYards {
                let y0 = g.point(distance: d, lateral: 0).y
                let y1 = g.point(distance: min(d + 25, g.maxYards), lateral: 0).y
                p.addRect(CGRect(x: 0, y: y1, width: g.size.width, height: max(0, y0 - y1)))
                d += 50
            }
        }
    }

    /// Putting green under the pin.
    private func green(_ g: RangeGeometry) -> some View {
        let center = g.point(distance: g.targetDistance, lateral: 0)
        let width = min(g.size.width * 0.44, 165)
        return ZStack {
            Ellipse()
                .fill(Scenery.greenSurface)
            Ellipse()
                .stroke(.white.opacity(0.25), lineWidth: 1)
        }
        .frame(width: width, height: 40)
        .position(x: center.x, y: center.y - 4)
    }

    private func targetWindow(_ g: RangeGeometry) -> some View {
        let target = g.point(distance: g.targetDistance, lateral: 0)
        let left = g.point(distance: g.targetDistance, lateral: -g.targetHalfWidth)
        let right = g.point(distance: g.targetDistance, lateral: g.targetHalfWidth)
        let near = g.point(distance: max(0, g.targetDistance - 18), lateral: 0)
        let far = g.point(distance: min(g.maxYards, g.targetDistance + 18), lateral: 0)
        let width = max(54, abs(right.x - left.x))
        let height = max(26, abs(near.y - far.y))

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.good.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.good.opacity(0.82), lineWidth: 1.8)
                }
                .frame(width: width, height: height)
                .position(target)

            Path { path in
                path.move(to: CGPoint(x: target.x - width * 0.38, y: target.y))
                path.addLine(to: CGPoint(x: target.x + width * 0.38, y: target.y))
                path.move(to: CGPoint(x: target.x, y: target.y - height * 0.32))
                path.addLine(to: CGPoint(x: target.x, y: target.y + height * 0.32))
            }
            .stroke(.white.opacity(0.42), lineWidth: 1)

            Text("±\(Int(g.targetHalfWidth)) yd")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.good)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
                .position(x: target.x, y: target.y - height / 2 - 10)
        }
    }

    private func yardGrid(_ g: RangeGeometry) -> some View {
        ForEach(g.yardMarks, id: \.self) { yards in
            let y = g.point(distance: yards, lateral: 0).y
            ZStack(alignment: .leading) {
                Path { p in
                    p.move(to: CGPoint(x: 12, y: y))
                    p.addLine(to: CGPoint(x: g.size.width - 12, y: y))
                }
                .stroke(.white.opacity(0.14), lineWidth: 1)

                Text("\(Int(yards))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
                    .position(x: 22, y: y - 8)
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
        let labelPoint = g.labelPoint(near: pt, yOffset: -18)
        return ZStack {
            Circle()
                .fill(Theme.face.opacity(0.18))
                .frame(width: 26, height: 26)
                .position(pt)

            Circle()
                .fill(Theme.face)
                .frame(width: 10, height: 10)
                .position(pt)

            Text("\(Int(g.carry)) yd | \(offlineLabel(g.offline))")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: Capsule())
                .position(labelPoint)
        }
    }

    private func teeMarker(_ g: RangeGeometry) -> some View {
        let tee = g.point(distance: 0, lateral: 0)
        return ZStack {
            Circle()
                .fill(.white)
                .stroke(Theme.face, lineWidth: 2)
                .frame(width: 13, height: 13)
                .position(tee)

            Text("TEE")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
                .position(x: tee.x, y: tee.y + 14)
        }
    }

    private func flightDots(_ g: RangeGeometry) -> some View {
        ForEach(1..<5) { index in
            let distance = g.carry * Double(index) / 5
            let point = g.point(distance: distance, lateral: g.lateral(at: distance))
            Circle()
                .fill(Theme.face.opacity(0.68 - Double(index) * 0.08))
                .frame(width: 5, height: 5)
                .position(point)
        }
    }

    private func pin(at pt: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 24, height: 24)
            Image(systemName: "flag.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.red)
        }
        .position(x: pt.x, y: pt.y - 6)
    }

    private func resultPill(_ g: RangeGeometry) -> some View {
        Text(resultText(g))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(resultColor(g))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow(.white.opacity(0.75), "Target")
            legendRow(Theme.path, "Start line")
            legendRow(Theme.face, "Ball flight")
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

    private func resultText(_ g: RangeGeometry) -> String {
        switch abs(g.offline) {
        case ...g.targetHalfWidth: return "Inside target"
        case ...(g.targetHalfWidth * 2): return "Playable miss"
        default: return "Big miss"
        }
    }

    private func resultColor(_ g: RangeGeometry) -> Color {
        switch abs(g.offline) {
        case ...g.targetHalfWidth: return Theme.good
        case ...(g.targetHalfWidth * 2): return Theme.warn
        default: return Theme.bad
        }
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

    var targetDistance: Double {
        min(maxYards * 0.92, max(carry, 1))
    }

    var targetHalfWidth: Double { 10 }

    /// Lateral span (yards) that fills half the width, with headroom for the curve.
    private var maxLateral: Double {
        max(35, abs(offline) * 1.4)
    }

    private var teeY: CGFloat { size.height - 18 }
    private var topY: CGFloat { 14 }
    private var teeX: CGFloat { size.width / 2 }

    func fairwayHalfWidth(at distance: Double) -> Double {
        let t = min(max(distance / maxYards, 0), 1)
        return 14 + 28 * pow(t, 0.72)
    }

    func point(distance d: Double, lateral: Double) -> CGPoint {
        let up = CGFloat(d / maxYards) * (teeY - topY)
        let xScale = (size.width / 2 - 16) / CGFloat(maxLateral)
        return CGPoint(x: teeX + CGFloat(lateral) * xScale, y: teeY - up)
    }

    func labelPoint(near point: CGPoint, yOffset: CGFloat) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 68), size.width - 68),
            y: min(max(point.y + yOffset, 18), size.height - 28)
        )
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
