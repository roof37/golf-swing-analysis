//
//  BiomechanicsView.swift
//  golf swing analysis
//
//  The Body tab: an animated golfer driven by capture-style body inputs
//  (pelvis / thorax / lead pressure / side bend / lead wrist / sequence),
//  grouped into Power and Strike controls, with a club toggle and a live
//  preview of the delivery the body produces — which can be sent to the
//  Impact tab.
//

import SwiftUI

struct BiomechanicsView: View {
    @Bindable var lab: SwingLab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faultLesson: String?
    @State private var progress: Double = 0.72   // 0 = address, 0.72 = impact, 1 = finish
    @State private var playing = false
    @State private var playStart = Date()
    @State private var playTask: Task<Void, Never>?
    @State private var rotationExpanded = true
    @State private var pressureExpanded = false
    @State private var faceExpanded = false
    @State private var patternsExpanded = false
    @State private var showGhost = false
    @State private var slowMotion = false
    @State private var selectedPage = 0
    @State private var showingMovementAnalysis = false

    private var bio: Biomechanics { lab.biomechanics }

    /// Playback rate: real-time, or quarter speed to study the delivery.
    private var playbackRate: Double { slowMotion ? 0.25 : 1.0 }

    /// Figure progress: pure clock math while playing, otherwise the scrubbed
    /// value. The wall clock maps through the engine's realistic frame times,
    /// so the downswing plays at the simulation's actual violence instead of
    /// a uniform crawl. Nothing is written during rendering — playback ends
    /// via the task started in `startPlayback`.
    private func liveProgress(now: Date) -> Double {
        guard playing else { return progress }
        return bio.engine.progress(atTime: now.timeIntervalSince(playStart) * playbackRate)
    }

    private func startPlayback() {
        playTask?.cancel()
        playStart = Date()
        playing = true
        let wallDuration = bio.engine.duration / playbackRate
        playTask = Task {
            try? await Task.sleep(for: .seconds(wallDuration))
            guard !Task.isCancelled else { return }
            progress = 1
            playing = false
        }
    }

    private func stopPlayback(at value: Double) {
        playTask?.cancel()
        playing = false
        progress = value
    }

    // MARK: - Phase label + callout

    private func swingPhase(_ pose: GolferPose) -> String {
        switch pose.progress {
        case ..<0.06: return "Address"
        case ..<0.50: return "Backswing"
        case ..<0.60: return "Top"
        case ..<0.72: return "Downswing"
        case ..<0.84: return "Impact"
        default: return "Follow-through"
        }
    }

    private func phaseCallout(_ pose: GolferPose) -> String {
        switch swingPhase(pose) {
        case "Address": return "Set up to the ball"
        case "Backswing": return "Turning back, hinging the wrists"
        case "Top": return "Top of backswing — fully coiled"
        case "Downswing":
            return bio.transitionSequence >= 70 ? "Pelvis first, holding lag" : "Casting — releasing early"
        case "Impact":
            let pressureWord = bio.leadPressure >= 70 ? "pressure forward" : "hanging back"
            let pelvisWord = bio.pelvisRotation >= 35 ? "pelvis open" : "pelvis stalled"
            return "\(pressureWord), \(pelvisWord)"
        default: return "Releasing to a balanced finish"
        }
    }

    private func phaseBanner(_ pose: GolferPose) -> some View {
        VStack(spacing: 2) {
            Text(swingPhase(pose)).font(.caption.bold())
            Text(phaseCallout(pose)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    /// The shot the current body positions would produce.
    private var previewSwing: SwingModel {
        var s = SwingModel()
        lab.biomechanics.apply(to: &s)
        return s
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    analyticalHeader
                        .padding(.horizontal, 16)
                    pageSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    TabView(selection: $selectedPage) {
                        clubMotionPage(height: proxy.size.height - 100)
                            .tag(0)
                        swingMechanicsPage(height: proxy.size.height - 100)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Swing Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var pageSelector: some View {
        HStack(spacing: 28) {
            pageButton("Club Motion", page: 0)
            pageButton("Swing Mechanics", page: 1)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(selectedPage == 0 ? Color.primary : Color.secondary.opacity(0.22)).frame(width: 5, height: 5)
                Circle().fill(selectedPage == 1 ? Color.primary : Color.secondary.opacity(0.22)).frame(width: 5, height: 5)
            }
        }
        .frame(height: 38)
    }

    private func pageButton(_ title: String, page: Int) -> some View {
        Button {
            if reduceMotion { selectedPage = page }
            else { withAnimation(.easeInOut(duration: 0.22)) { selectedPage = page } }
        } label: {
            Text(title)
                .font(.subheadline.weight(selectedPage == page ? .semibold : .regular))
                .foregroundStyle(selectedPage == page ? Color.primary : Color.secondary)
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selectedPage == page ? Color.primary : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func clubMotionPage(height: CGFloat) -> some View {
        motionAnalysisCard(viewerHeight: max(230, height - 170))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    private func swingMechanicsPage(height: CGFloat) -> some View {
        VStack(spacing: 6) {
            SwingGeometryTool(
                measuredLowPoint: bio.lowPointPastBall,
                club: bio.club,
                angleOfAttack: lab.swing.angleOfAttack,
                dynamicLoft: lab.swing.dynamicLoft
            )
            Button {
                showingMovementAnalysis = true
            } label: {
                Label("Movement Inputs", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingMovementAnalysis) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        rotationSequenceCard
                        mechanicsHeader
                        pressureLowPointCard
                        faceDeliveryCard
                        faultPicker
                        actionButtons
                    }
                    .padding()
                }
                .navigationTitle("Movement Inputs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingMovementAnalysis = false }
                    }
                }
            }
        }
    }

    // MARK: - Motion analysis

    private var analyticalHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Menu {
                    Picker("Club", selection: $lab.biomechanics.club) {
                        ForEach(Biomechanics.Club.allCases) { club in
                            Text(club.rawValue).tag(club)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(bio.club.rawValue).font(.headline)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .foregroundStyle(.primary)
                }
                Spacer()
                Text("Live model")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Divider()
        }
    }

    private func motionAnalysisCard(viewerHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLUB MOTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TimelineView(.animation(paused: !playing)) { tl in
                let t = liveProgress(now: tl.date)
                let pose = bio.engine.pose(at: t)

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(swingPhase(pose).uppercased()).font(.caption2.weight(.semibold))
                        Text(phaseCallout(pose)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SwingStageView(
                        pose: pose,
                        bio: bio,
                        viewAngle: .spatial,
                        subject: .club,
                        showGhost: showGhost,
                        presentation: .motion
                    )
                    .frame(height: viewerHeight)
                    .frame(maxWidth: .infinity)

                    technicalTimeline(progress: t)

                    HStack {
                        stageToggles
                        Spacer()
                        Button {
                            playing ? stopPlayback(at: t) : startPlayback()
                        } label: {
                            Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func compactChoice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? Color.accentColor : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func technicalTimeline(progress: Double) -> some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.16)).frame(height: 2)
                    Capsule().fill(Color.primary.opacity(0.55)).frame(width: width * progress, height: 2)
                    ForEach([0.0, SwingEngine.Output.topProgress, SwingEngine.Output.impactProgress, 1.0], id: \.self) { event in
                        Circle()
                            .fill(abs(progress - event) < 0.035 ? Color.accentColor : Color(.systemBackground))
                            .overlay(Circle().stroke(.secondary.opacity(0.65), lineWidth: 1))
                            .frame(width: 9, height: 9)
                            .offset(x: width * event - 4.5)
                    }
                    Circle().fill(Color.accentColor).frame(width: 5, height: 14)
                        .offset(x: width * progress - 2.5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    stopPlayback(at: min(1, max(0, value.location.x / width)))
                })
            }
            .frame(height: 18)
            phaseRuler
        }
    }

    /// Ghost-comparison and slow-motion chips on the stage.
    private var stageToggles: some View {
        HStack(spacing: 6) {
            stageChip("Ghost", systemImage: "square.on.square.dashed", active: showGhost) {
                showGhost.toggle()
            }
            stageChip(slowMotion ? "¼×" : "1×", systemImage: "gauge.with.needle", active: slowMotion) {
                slowMotion.toggle()
            }
        }
        .padding(.vertical, 4)
    }

    private func stageChip(_ title: String, systemImage: String, active: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(active ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(.thinMaterial),
                            in: Capsule())
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    /// Phase labels aligned to where the phases actually live on the
    /// timeline (top of backswing at 0.55, impact at 0.72).
    private var phaseRuler: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Text("Address")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Top")
                    .position(x: w * CGFloat(SwingEngine.Output.topProgress), y: 6)
                Text("Impact")
                    .position(x: w * CGFloat(SwingEngine.Output.impactProgress), y: 6)
                Text("Finish")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(height: 12)
    }

    private var clubPicker: some View {
        Picker("Club", selection: $lab.biomechanics.club) {
            ForEach(Biomechanics.Club.allCases) { club in
                Text(club.rawValue).tag(club)
            }
        }
        .pickerStyle(.segmented)
    }

    private var contextualMeasurements: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                instrumentMetric("LOW POINT", lowPointFriendlyText)
                instrumentMetric("CLUB PATH", String(format: "%+.1f°", bio.clubPath))
                instrumentMetric("AoA", String(format: "%+.1f°", bio.angleOfAttack))
            }
            Divider()
            HStack(alignment: .top, spacing: 18) {
                instrumentMetric("FACE", String(format: "%+.1f°", bio.faceAngle))
                instrumentMetric("SHAFT LEAN", String(format: "%+.1f°", bio.shaftLean))
                instrumentMetric("SPEED", String(format: "%.0f mph", bio.swingSpeed))
            }
        }
        .padding(.vertical, 8)
    }

    private func instrumentMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lowPointFriendlyText: String {
        let value = bio.lowPointPastBall
        if abs(value) < 1 { return "At ball" }
        return String(format: "%.0f cm %@", abs(value), value > 0 ? "ahead" : "behind")
    }

    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            interpretationBlock("WHAT HAPPENED", whatHappened)
            interpretationBlock("WHY IT MATTERS", whyItMatters)
            Button {
                pressureExpanded = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WORK ON").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Low Point Control")
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    private func interpretationBlock(_ heading: String, _ copy: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(copy).font(.subheadline).foregroundStyle(.primary)
        }
    }

    private var whatHappened: String {
        let value = abs(bio.lowPointPastBall)
        if value < 1 { return "The club reached its lowest point at the ball." }
        return String(format: "The club reached its lowest point %.0f cm %@ the ball.", value, bio.lowPointPastBall > 0 ? "ahead of" : "behind")
    }

    private var whyItMatters: String {
        if bio.lowPointPastBall < -1 {
            return bio.club == .driver
                ? "A low point behind the teed ball supports an upward strike."
                : "A low point behind the ball can reduce compression and contact consistency."
        }
        if bio.lowPointPastBall > 1 { return "A low point ahead of the ball supports a descending, ball-first strike." }
        return "Low point near the ball produces a relatively neutral strike."
    }

    private var mechanicsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("MECHANICS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("Adjust the movement inputs behind the measured delivery.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var compactDeliverySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mechanics Snapshot")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(mechanicsSnapshotTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                Text(String(format: "%.0f mph", bio.swingSpeed))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                deliveryMetric("X-Factor", String(format: "%+.0f°", bio.separation), qualityColor(bio.separationQuality))
                deliveryMetric("Sequence", "\(Int(bio.transitionSequence))%", .primary)
                deliveryMetric("Low Point", lowPointShortText, bio.lowPointPastBall >= 0 ? .primary : .secondary)
                deliveryMetric("AoA", String(format: "%+.1f°", bio.angleOfAttack), .primary)
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private var mechanicsSnapshotTitle: String {
        switch bio.separationQuality {
        case .good: return "Sequenced rotation with usable separation"
        case .ok: return "Usable motion, but timing window is narrow"
        case .poor: return "Sequence leak: rotation is not transferring cleanly"
        }
    }

    private var lowPointShortText: String {
        let v = bio.lowPointPastBall
        if abs(v) < 1 { return "Ball" }
        return String(format: "%.0f cm %@", abs(v), v > 0 ? "past" : "back")
    }

    // MARK: - Control groups

    /// Rotation and timing: how body segments create and transfer speed.
    private var rotationSequenceCard: some View {
        CardSection("Rotation & Sequence", systemImage: "arrow.triangle.2.circlepath") {
            DisclosureGroup(isExpanded: $rotationExpanded) {
                VStack(spacing: 10) {
                    control("Pelvis Rotation", $lab.biomechanics.pelvisRotation, 0...70, low: "Closed", high: "Open", effect: bio.pelvisEffect,
                            info: "How open the pelvis is at impact. Clearing the pelvis creates room for the arms and starts the lead-side rotational chain.")
                    control("Thorax Rotation", $lab.biomechanics.thoraxRotation, -20...50, low: "Closed", high: "Open", effect: bio.thoraxEffect,
                            info: "How open the rib cage is at impact. The thorax should arrive after the pelvis; if it outraces the sequence, path shifts left.")
                    separationCard
                    control("Transition Sequence", $lab.biomechanics.transitionSequence, 0...100, low: "Out of sync", high: "Efficient", unit: "%", step: 1, effect: bio.sequenceEffect,
                            info: "The order and timing of pelvis -> torso -> arm -> club in the downswing. Better sequencing lets speed peak later, closer to impact.")
                    KinematicSequenceView(segments: bio.sequence)
                        .frame(height: 132)
                }
                .padding(.top, 8)
            } label: {
                controlSummary("Pelvis \(Int(bio.pelvisRotation))° | Thorax \(Int(bio.thoraxRotation))° | Seq \(Int(bio.transitionSequence))%")
            }
        }
    }

    /// Pressure and tilt: how the body places the bottom of the swing arc.
    private var pressureLowPointCard: some View {
        CardSection("Pressure & Low Point", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") {
            DisclosureGroup(isExpanded: $pressureExpanded) {
                VStack(spacing: 10) {
                    control("Lead Pressure", $lab.biomechanics.leadPressure, 50...95, low: "Trail", high: "Lead", unit: "%", step: 1, effect: bio.pressureEffect,
                            info: "How much pressure is on the lead foot at impact. More lead pressure tends to move the low point forward.")
                    control("Side Bend", $lab.biomechanics.sideBend, 0...30, low: "Level", high: "Behind ball", effect: bio.sideBendEffect,
                            info: "Secondary tilt of the trunk away from the target. More side bend keeps the upper body behind the ball and pulls the low point back.")
                    lowPointCard
                }
                .padding(.top, 8)
            } label: {
                controlSummary("Lead \(Int(bio.leadPressure))% | Side bend \(Int(bio.sideBend))° | LP \(lowPointShortText)")
            }
        }
    }

    /// Face delivery: how wrist condition resolves into face angle and loft.
    private var faceDeliveryCard: some View {
        CardSection("Face Delivery", systemImage: "rectangle.and.hand.point.up.left") {
            DisclosureGroup(isExpanded: $faceExpanded) {
                VStack(spacing: 10) {
                    control("Lead Wrist", $lab.biomechanics.leadWrist, -20...20, low: "Bowed", high: "Cupped", effect: bio.wristEffect,
                            info: "Lead wrist shape owns the face: bowed closes and de-lofts it; cupped opens and adds loft.")
                    deliveryMappingCard
                }
                .padding(.top, 8)
            } label: {
                controlSummary(String(format: "Wrist %+.0f° | Face %+.1f° | Loft %.1f°", bio.leadWrist, bio.faceAngle, bio.dynamicLoft))
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                lab.sendBodyToImpact()
                lab.selectedTab = .impact
            } label: {
                Label("Send", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                let club = lab.biomechanics.club
                lab.biomechanics = Biomechanics()
                lab.biomechanics.club = club
                faultLesson = nil
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var faultPicker: some View {
        CardSection("Patterns", systemImage: "target") {
            DisclosureGroup(isExpanded: $patternsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BodyFault.library) { fault in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.6)) { fault.apply(to: &lab.biomechanics) }
                                    faultLesson = fault.lesson
                                } label: {
                                    Text(fault.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(.tint.opacity(0.14), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let faultLesson {
                        Text(faultLesson)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                controlSummary(faultLesson == nil ? "Load common body patterns" : "Pattern loaded")
            }
        }
    }

    private var deliveryStatus: String {
        switch abs(previewSwing.landingOffline) {
        case ..<6: return "Linked"
        case ..<20: return "Shaped"
        default: return "Big Miss"
        }
    }

    private var deliveryColor: Color {
        switch abs(previewSwing.landingOffline) {
        case ..<6: return Theme.good
        case ..<20: return Theme.warn
        default: return Theme.bad
        }
    }

    private var deliveryAttackColor: Color {
        abs(bio.angleOfAttack) <= 4 ? Theme.good : Theme.warn
    }

    private func controlSummary(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deliveryMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func control(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                         low: String, high: String, unit: String = "°", step: Double = 0.5,
                         effect: String, info: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ParameterSlider(title: title, value: value, range: range, unit: unit, lowLabel: low, highLabel: high, step: step, info: info)
            Text(effect).font(.caption2).italic().foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var separationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pelvis–Thorax Separation").font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%+.0f°", bio.separation))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(qualityColor(bio.separationQuality))
            }
            SeparationBar(separation: bio.separation).frame(height: 14)
            Text(bio.separationNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Shows where the arc bottoms out relative to the ball — the one number
    /// that drives attack angle, shaft lean, and dynamic loft together.
    private var lowPointCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Low Point vs. Ball").font(.subheadline.weight(.medium))
                Spacer()
                Text(lowPointText)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(bio.lowPointPastBall >= 0 ? Theme.path : Theme.face)
            }
            LowPointBar(pastBall: bio.lowPointPastBall)
                .frame(height: 30)
            Text(lowPointNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deliveryMappingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Delivered Club").font(.subheadline.weight(.medium))
                Spacer()
                Text(bio.club.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                deliveryMetric("Face", String(format: "%+.1f°", bio.faceAngle), Theme.face)
                deliveryMetric("Path", String(format: "%+.1f°", bio.clubPath), Theme.path)
                deliveryMetric("Loft", String(format: "%.1f°", bio.dynamicLoft), .primary)
                deliveryMetric("Lean", String(format: "%+.1f°", bio.shaftLean), .primary)
                deliveryMetric("AoA", String(format: "%+.1f°", bio.angleOfAttack), deliveryAttackColor)
                deliveryMetric("Speed", String(format: "%.0f mph", bio.swingSpeed), .primary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var lowPointText: String {
        let v = bio.lowPointPastBall
        if abs(v) < 1 { return "At the ball" }
        return String(format: "%.0f cm %@", abs(v), v > 0 ? "past" : "before")
    }

    private var lowPointNote: String {
        if bio.lowPointPastBall > 1 {
            return "Arc bottoms past the ball — a descending, ball-first strike with forward lean."
        }
        if bio.lowPointPastBall < -1 {
            return bio.club == .driver
                ? "Arc bottoms before the ball — hitting up on the driver, exactly what the tee is for."
                : "Arc bottoms before the ball — with an iron that's scoop territory: fat or thin."
        }
        return "Arc bottoms at the ball — clean, neutral contact."
    }

    private func qualityColor(_ q: Biomechanics.Quality) -> Color {
        switch q {
        case .poor: return .red
        case .ok: return .orange
        case .good: return .green
        }
    }
}

// MARK: - Interactive swing-geometry instrument

private enum SwingGeometryPreset: String, CaseIterable, Identifiable {
    case teeOff = "Tee Off"
    case fairway = "Fairway"
    case threeX = "3x"
    case sandWedge = "SW"

    var id: String { rawValue }

    var values: (radius: Double, distance: Double, height: Double, plane: Double) {
        switch self {
        case .teeOff: return (112, -6, -4, 55)
        case .fairway: return (100, 11, -10, 70)
        case .threeX: return (78, 6, -14, 72)
        case .sandWedge: return (92, 8, -12, 68)
        }
    }
}

private struct SwingGeometryTool: View {
    let measuredLowPoint: Double
    let club: Biomechanics.Club
    let angleOfAttack: Double
    let dynamicLoft: Double

    @State private var selectedPreset: SwingGeometryPreset
    @State private var swingRadius: Double
    @State private var lowPointDistance: Double
    @State private var lowPointHeight: Double
    @State private var swingPlane: Double

    init(measuredLowPoint: Double, club: Biomechanics.Club, angleOfAttack: Double, dynamicLoft: Double) {
        self.measuredLowPoint = measuredLowPoint
        self.club = club
        self.angleOfAttack = angleOfAttack
        self.dynamicLoft = dynamicLoft
        _selectedPreset = State(initialValue: club == .driver ? .teeOff : .fairway)
        _swingRadius = State(initialValue: club == .driver ? 112 : 100)
        _lowPointDistance = State(initialValue: measuredLowPoint)
        _lowPointHeight = State(initialValue: club == .driver ? -4 : -8)
        _swingPlane = State(initialValue: club == .driver ? 55 : 63)
    }

    var body: some View {
        GeometryReader { proxy in
            let visualizationHeight = min(330, max(180, proxy.size.height - 260))
            VStack(alignment: .leading, spacing: 8) {
                Text("SWING MECHANICS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(SwingGeometryPreset.allCases) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.caption.weight(selectedPreset == preset ? .semibold : .regular))
                                .foregroundStyle(selectedPreset == preset ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selectedPreset == preset ? Theme.inset : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                LowPointGeometryCanvas(
                    radius: swingRadius,
                    distance: lowPointDistance,
                    height: lowPointHeight,
                    plane: swingPlane
                )
                .frame(height: visualizationHeight)

                VStack(spacing: 5) {
                    geometrySlider("Swing Radius", value: $swingRadius, range: 70...130, step: 1,
                                   valueText: "\(Int(swingRadius)) cm")
                    geometrySlider("Low Point Distance", value: $lowPointDistance, range: -24...24, step: 0.5,
                                   valueText: distanceText)
                    geometrySlider("Low Point Height", value: $lowPointHeight, range: -40...60, step: 1,
                                   valueText: String(format: "%+.0f mm", lowPointHeight))
                    geometrySlider("Swing Plane", value: $swingPlane, range: 45...90, step: 1,
                                   valueText: "\(Int(swingPlane))°")
                }

                HStack(spacing: 0) {
                    modelOutput("AoA", String(format: "%+.1f°", angleOfAttack))
                    Divider().frame(height: 28)
                    modelOutput("Dynamic Loft", String(format: "%.1f°", dynamicLoft))
                }
                .accessibilityElement(children: .contain)
            }
        }
        .onChange(of: club) { _, newClub in
            applyPreset(newClub == .driver ? .teeOff : .fairway, useMeasuredLowPoint: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func applyPreset(_ preset: SwingGeometryPreset, useMeasuredLowPoint: Bool = false) {
        selectedPreset = preset
        let values = preset.values
        swingRadius = values.radius
        lowPointDistance = useMeasuredLowPoint ? measuredLowPoint : values.distance
        lowPointHeight = values.height
        swingPlane = values.plane
    }

    private func geometrySlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                                step: Double, valueText: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.caption.weight(.medium))
                Spacer()
                Text(valueText).font(.caption.weight(.semibold).monospacedDigit())
            }
            Slider(value: value, in: range, step: step)
                .tint(Color(red: 0.67, green: 0.52, blue: 0.30))
        }
    }

    private func modelOutput(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(title.uppercased()).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private var distanceText: String {
        if abs(lowPointDistance) < 0.25 { return "0 cm" }
        return String(format: "%.1f cm %@", abs(lowPointDistance), lowPointDistance > 0 ? "ahead" : "behind")
    }
}

private struct LowPointGeometryCanvas: View {
    let radius: Double
    let distance: Double
    let height: Double
    let plane: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let heightPx = geo.size.height
            let groundY = heightPx * 0.70
            let ballX = width * 0.48
            let centimetersToPixels = min(width / 68, heightPx / 46)
            let lowX = ballX + CGFloat(distance) * centimetersToPixels
            let lowY = groundY - CGFloat(height / 10) * centimetersToPixels
            let radiusPx = CGFloat(radius) * centimetersToPixels
            let clubX = ballX - width * 0.13
            let clubY = arcY(x: clubX, lowX: lowX, lowY: lowY, radius: radiusPx, plane: plane)

            ZStack {
                Color(.systemBackground)

                // Swing plane reference: steeper planes appear narrower.
                Ellipse()
                    .stroke(Theme.path.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
                    .frame(width: width * 0.82,
                           height: heightPx * CGFloat(0.22 + 0.30 * sin(plane * .pi / 180)))
                    .position(x: width * 0.48, y: heightPx * 0.40)

                Path { path in
                    path.move(to: CGPoint(x: 14, y: groundY))
                    path.addLine(to: CGPoint(x: width - 14, y: groundY))
                }
                .stroke(.secondary.opacity(0.35), lineWidth: 1.2)

                Path { path in
                    let steps = 72
                    for index in 0...steps {
                        let x = width * (0.06 + 0.88 * CGFloat(index) / CGFloat(steps))
                        let point = CGPoint(x: x, y: arcY(x: x, lowX: lowX, lowY: lowY,
                                                         radius: radiusPx, plane: plane))
                        index == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                }
                .stroke(Color(red: 0.67, green: 0.52, blue: 0.30),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))

                targetArrow(from: CGPoint(x: ballX, y: groundY + 18), width: width)

                Circle().fill(.white).stroke(.secondary, lineWidth: 1.2)
                    .frame(width: 13, height: 13).position(x: ballX, y: groundY - 7)
                Text("BALL").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    .position(x: ballX, y: groundY + 11)

                Circle().fill(Theme.face).frame(width: 9, height: 9).position(x: lowX, y: lowY)
                Text("LOW POINT").font(.system(size: 8, weight: .semibold)).foregroundStyle(Theme.face)
                    .position(x: lowX, y: lowY + 16)

                measurement(from: lowX, to: ballX, y: min(heightPx - 22, groundY + 38))

                // Minimal instrumented club at a sampled point on the arc.
                Path { path in
                    path.move(to: CGPoint(x: clubX, y: clubY))
                    let radians = CGFloat(plane) * .pi / 180
                    path.addLine(to: CGPoint(x: clubX + cos(radians) * 112, y: clubY - sin(radians) * 112))
                }
                .stroke(.secondary.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Capsule().fill(.primary.opacity(0.88)).frame(width: 24, height: 8)
                    .rotationEffect(.degrees(-8)).position(x: clubX, y: clubY)

                Text("PLANE \(Int(plane))°")
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.path)
                    .position(x: width - 52, y: 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.12), lineWidth: 1))
    }

    private func arcY(x: CGFloat, lowX: CGFloat, lowY: CGFloat, radius: CGFloat, plane: Double) -> CGFloat {
        let horizontal = min(abs(x - lowX), radius * 0.98)
        let circularRise = radius - sqrt(max(radius * radius - horizontal * horizontal, 0))
        return lowY - circularRise * CGFloat(sin(plane * .pi / 180))
    }

    private func measurement(from start: CGFloat, to end: CGFloat, y: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: start, y: y)); path.addLine(to: CGPoint(x: end, y: y))
            path.move(to: CGPoint(x: start, y: y - 4)); path.addLine(to: CGPoint(x: start, y: y + 4))
            path.move(to: CGPoint(x: end, y: y - 4)); path.addLine(to: CGPoint(x: end, y: y + 4))
        }
        .stroke(Theme.face.opacity(0.65), lineWidth: 1)
    }

    private func targetArrow(from origin: CGPoint, width: CGFloat) -> some View {
        Path { path in
            path.move(to: origin); path.addLine(to: CGPoint(x: width - 18, y: origin.y))
            path.move(to: CGPoint(x: width - 25, y: origin.y - 4)); path.addLine(to: CGPoint(x: width - 18, y: origin.y))
            path.addLine(to: CGPoint(x: width - 25, y: origin.y + 4))
        }
        .stroke(Theme.path.opacity(0.65), lineWidth: 1.3)
    }
}

// MARK: - Front-on golfer figure

/// A snapshot of the figure's drawable positions. Built either at impact (static)
/// or interpolated across a swing (animated).
struct GolferPose {
    var shoulder: Double
    var hip: Double
    var spine: Double
    var weight: Double       // 0…1 onto the lead foot
    var armAngle: Double     // hands' orbit around the chest (0 = down at the ball)
    var clubAngle: Double    // clubhead direction (0 = straight down at the ball)
    var wrist: Double
    /// true while mid-swing, so labels can hide.
    var swinging: Bool = false
    /// 0…1 progress through the swing (used for fault coloring near impact).
    var progress: Double = 1.0

    static func impact(_ bio: Biomechanics) -> GolferPose {
        GolferPose(shoulder: bio.thoraxRotation, hip: bio.pelvisRotation, spine: bio.sideBend,
                   weight: (bio.leadPressure - 50) / 45, armAngle: 0, clubAngle: 0, wrist: bio.leadWrist)
    }
}

// MARK: - Static teaching avatar (used by the Research tab)

/// A polished teaching avatar for topic pages. The rendering is intentionally
/// schematic: it shows the body pieces that matter to delivery without trying to
/// be a realistic anatomical model.
struct GolferFigure: View {
    let pose: GolferPose

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let unit = min(w, h) / 320
            let centerX = w / 2
            let groundY = h * 0.84
            let sway = CGFloat(pose.weight - 0.5) * -74 * unit
            let hipCenter = CGPoint(x: centerX + sway, y: h * 0.60)
            let shoulderCenter = CGPoint(x: hipCenter.x + CGFloat(pose.spine) * 0.75 * unit, y: h * 0.37)
            let headCenter = CGPoint(x: shoulderCenter.x + CGFloat(pose.spine) * 0.24 * unit, y: h * 0.22)
            let shoulderLine = segment(center: shoulderCenter, length: 116 * unit, degrees: -pose.shoulder)
            let hipLine = segment(center: hipCenter, length: 90 * unit, degrees: -pose.hip)
            let leadFoot = CGPoint(x: centerX - 56 * unit, y: groundY)
            let trailFoot = CGPoint(x: centerX + 56 * unit, y: groundY)
            let hands = point(from: shoulderCenter, length: 86 * unit, degrees: pose.armAngle + 92)
            let clubhead = point(from: hands, length: 98 * unit, degrees: pose.clubAngle + 92)
            let ball = CGPoint(x: centerX - 14 * unit, y: groundY - 7 * unit)

            ZStack {
                studioBackground(width: w, height: h, unit: unit)
                targetLine(x: centerX, height: h)
                swingArc(center: shoulderCenter, radius: 92 * unit)
                    .stroke(.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

                pressurePlate(at: leadFoot, title: "Lead", loaded: pose.weight)
                pressurePlate(at: trailFoot, title: "Trail", loaded: 1 - pose.weight)

                line(hipCenter, leadFoot)
                    .stroke(.primary.opacity(0.55 + 0.35 * pose.weight), style: stroke(8 * unit))
                line(hipCenter, trailFoot)
                    .stroke(.primary.opacity(0.90 - 0.30 * pose.weight), style: stroke(8 * unit))

                torsoSilhouette(shoulderCenter: shoulderCenter, hipCenter: hipCenter, unit: unit)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                line(hipCenter, shoulderCenter)
                    .stroke(.primary.opacity(0.55), style: stroke(6 * unit))
                line(hipLine.start, hipLine.end)
                    .stroke(hipColor(pose), style: stroke(10 * unit))
                line(shoulderLine.start, shoulderLine.end)
                    .stroke(shoulderColor(pose), style: stroke(11 * unit))

                line(shoulderLine.start, hands)
                    .stroke(.primary.opacity(0.86), style: stroke(5 * unit))
                line(shoulderLine.end, hands)
                    .stroke(.primary.opacity(0.86), style: stroke(5 * unit))
                line(hands, clubhead)
                    .stroke(.secondary, style: stroke(3 * unit))

                wristFace(at: hands, unit: unit)
                clubHead(at: clubhead, unit: unit)
                ballView(at: ball, unit: unit)
                headView(at: headCenter, unit: unit)

                cuePanel(
                    shoulderColor: shoulderColor(pose),
                    hipColor: hipColor(pose),
                    pressure: pose.weight
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(9)
            }
        }
    }

    private func studioBackground(width: CGFloat, height: CGFloat, unit: CGFloat) -> some View {
        let groundY = height * 0.84
        return ZStack {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(.systemBlue).opacity(0.10), location: 0),
                            .init(color: Color(.systemBackground).opacity(0.12), location: 0.5),
                            .init(color: Theme.field, location: 0.84),
                            .init(color: Color(.systemGreen).opacity(0.18), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Distant tree line sitting on the ground line behind the golfer.
            TreeLineShape(seed: 5)
                .fill(Scenery.treeLine.opacity(0.14))
                .frame(width: width, height: 24)
                .position(x: width / 2, y: groundY - 12)

            HorizonHaze(width: width, horizon: groundY * 0.4)

            GrassTexture(bladeCount: 30, tint: Color(.systemGreen).opacity(0.45))
                .frame(width: width, height: height - groundY)
                .position(x: width / 2, y: (height + groundY) / 2)
        }
    }

    private func targetLine(x: CGFloat, height: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: height * 0.12))
            path.addLine(to: CGPoint(x: x, y: height * 0.91))
        }
        .stroke(.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
    }

    private func cuePanel(shoulderColor: Color, hipColor: Color, pressure: Double) -> some View {
        HStack(spacing: 7) {
            cueItem(shoulderColor, "Thorax")
            cueItem(hipColor, "Pelvis")
            cueItem(.green, "\(Int(pressure * 100))% lead")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
    }

    private func cueItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.system(size: 9, weight: .medium))
        }
    }

    // MARK: - Fault-aware coloring

    /// Thorax bar turns red when outside the ideal range (~0–40° open at impact).
    /// During the swing, fault coloring appears in the impact zone (progress 0.65–0.85)
    /// so the user sees the problem flash as the club comes through.
    private func shoulderColor(_ pose: GolferPose) -> Color {
        let faulted = pose.shoulder < -5 || pose.shoulder > 40
        if pose.swinging {
            let nearImpact = (0.65...0.85).contains(pose.progress)
            return (nearImpact && faulted) ? .red : .blue
        }
        return faulted ? .red : .blue
    }

    /// Pelvis bar turns red when outside the ideal range (~20–55° open at impact).
    private func hipColor(_ pose: GolferPose) -> Color {
        let faulted = pose.hip < 20 || pose.hip > 55
        if pose.swinging {
            let nearImpact = (0.65...0.85).contains(pose.progress)
            return (nearImpact && faulted) ? .red : .orange
        }
        return faulted ? .red : .orange
    }

    // MARK: - Drawing helpers

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        Path { p in p.move(to: a); p.addLine(to: b) }
    }

    private func point(from origin: CGPoint, length: CGFloat, degrees: Double) -> CGPoint {
        let radians = CGFloat(degrees) * .pi / 180
        return CGPoint(x: origin.x + cos(radians) * length, y: origin.y + sin(radians) * length)
    }

    private func segment(center: CGPoint, length: CGFloat, degrees: Double) -> (start: CGPoint, end: CGPoint) {
        let angle = CGFloat(degrees) * .pi / 180
        let dx = cos(angle) * length / 2
        let dy = sin(angle) * length / 2
        return (
            CGPoint(x: center.x - dx, y: center.y - dy),
            CGPoint(x: center.x + dx, y: center.y + dy)
        )
    }

    private func torsoSilhouette(shoulderCenter: CGPoint, hipCenter: CGPoint, unit: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: shoulderCenter.x - 42 * unit, y: shoulderCenter.y + 8 * unit))
            path.addQuadCurve(
                to: CGPoint(x: shoulderCenter.x + 42 * unit, y: shoulderCenter.y + 8 * unit),
                control: CGPoint(x: shoulderCenter.x, y: shoulderCenter.y - 10 * unit)
            )
            path.addLine(to: CGPoint(x: hipCenter.x + 30 * unit, y: hipCenter.y - 8 * unit))
            path.addQuadCurve(
                to: CGPoint(x: hipCenter.x - 30 * unit, y: hipCenter.y - 8 * unit),
                control: CGPoint(x: hipCenter.x, y: hipCenter.y + 8 * unit)
            )
            path.closeSubpath()
        }
    }

    private func pressurePlate(at point: CGPoint, title: String, loaded: Double) -> some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(.green.opacity(0.12 + 0.34 * loaded))
                .overlay {
                    Capsule().stroke(.green.opacity(0.28), lineWidth: 1)
                }
                .frame(width: 48, height: 14)
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .position(x: point.x, y: point.y + 12)
    }

    private func swingArc(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(70),
                endAngle: .degrees(250),
                clockwise: false
            )
        }
    }

    private func wristFace(at point: CGPoint, unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3 * unit)
            .fill(.purple)
            .frame(width: 26 * unit, height: 7 * unit)
            .rotationEffect(.degrees(pose.wrist))
            .position(point)
    }

    private func clubHead(at point: CGPoint, unit: CGFloat) -> some View {
        Capsule()
            .fill(.gray)
            .frame(width: 24 * unit, height: 9 * unit)
            .rotationEffect(.degrees(pose.clubAngle))
            .position(point)
    }

    private func ballView(at point: CGPoint, unit: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .stroke(.secondary, lineWidth: 1.5)
            .frame(width: 11 * unit, height: 11 * unit)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .position(point)
    }

    private func headView(at point: CGPoint, unit: CGFloat) -> some View {
        Circle()
            .fill(.primary.opacity(0.88))
            .frame(width: 31 * unit, height: 31 * unit)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.20))
                    .frame(width: 18 * unit, height: 4 * unit)
                    .offset(y: 7 * unit)
            }
            .position(point)
    }
}

// MARK: - Separation range bar (ideal zone)

struct SeparationBar: View {
    let separation: Double
    private let minV = -10.0
    private let maxV = 60.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { v in
                CGFloat((min(max(v, minV), maxV) - minV) / (maxV - minV)) * w
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                // Ideal zone 15–35°.
                Capsule().fill(.green.opacity(0.4))
                    .frame(width: x(35) - x(15))
                    .offset(x: x(15))
                // Current value marker.
                Capsule().fill(.primary)
                    .frame(width: 3)
                    .offset(x: x(separation) - 1.5)
            }
        }
    }
}

// MARK: - Low-point bar (arc bottom vs. ball)

/// Shows where the swing arc bottoms out relative to the ball: before it
/// (ascending strike) or past it (descending, ball-first).
struct LowPointBar: View {
    /// cm past the ball (+ = descending strike, − = ascending).
    let pastBall: Double
    private let range = 20.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let ballX = w * 0.5
            let clamped = min(max(pastBall, -range), range)
            let bottomX = ballX + CGFloat(clamped / range) * (w * 0.42)

            ZStack {
                // Shallow arc hinting at the swing, bottoming at bottomX.
                Path { path in
                    path.move(to: CGPoint(x: bottomX - w * 0.42, y: 2))
                    path.addQuadCurve(
                        to: CGPoint(x: bottomX + w * 0.42, y: 2),
                        control: CGPoint(x: bottomX, y: h + 10)
                    )
                }
                .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))

                // Ground.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - 4))
                    path.addLine(to: CGPoint(x: w, y: h - 4))
                }
                .stroke(.green.opacity(0.4), lineWidth: 2)

                // Ball at center.
                Circle()
                    .fill(.white)
                    .stroke(.secondary, lineWidth: 1)
                    .frame(width: 9, height: 9)
                    .position(x: ballX, y: h - 9)

                // Arc bottom marker.
                Circle()
                    .fill(pastBall >= 0 ? Theme.path : Theme.face)
                    .frame(width: 7, height: 7)
                    .position(x: bottomX, y: h - 8)
            }
        }
    }
}

// MARK: - Kinematic sequence chart

/// A simple timeline showing when each segment peaks. Properly sequenced swings
/// stagger pelvis → torso → arm → club; poor ones bunch up.
struct KinematicSequenceView: View {
    let segments: [Biomechanics.Segment]

    private let labelWidth: CGFloat = 52
    private let timeWidth: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kinematic Sequence")
                    .font(.headline)
                Spacer()
                Text("Peak speed timing")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let railWidth = max(1, geo.size.width - labelWidth - timeWidth - 18)

                VStack(spacing: 9) {
                    sequenceHeader(railWidth: railWidth)
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                        sequenceRow(index: index, segment: seg, railWidth: railWidth)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.inset.opacity(0.70), in: RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func sequenceHeader(railWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text("Segment")
                .frame(width: labelWidth, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.10))
                Rectangle()
                    .fill(.secondary.opacity(0.24))
                    .frame(width: 1, height: 16)
                    .offset(x: railWidth * 0.72)
            }
            .frame(width: railWidth, height: 8)
            Text("Peak")
                .frame(width: timeWidth, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .semibold).monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func sequenceRow(index: Int, segment: Biomechanics.Segment, railWidth: CGFloat) -> some View {
        let peakX = min(max(CGFloat(segment.peakTime) * railWidth, 0), railWidth)
        let accent = color(for: segment.color)

        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(segment.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(width: labelWidth, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.11))
                Capsule()
                    .fill(accent.opacity(0.22))
                    .frame(width: max(peakX, 4))
                Circle()
                    .fill(accent)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle().stroke(.white.opacity(0.70), lineWidth: 1)
                    }
                    .offset(x: max(0, min(peakX - 6.5, railWidth - 13)))
            }
            .frame(width: railWidth, height: 13)

            Text(String(format: "%.2f", segment.peakTime))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: timeWidth, alignment: .trailing)
        }
    }

    private func color(for c: Biomechanics.SegmentColor) -> Color {
        switch c {
        case .pelvis: return .primary.opacity(0.78)
        case .torso: return Theme.path.opacity(0.78)
        case .arm: return .secondary.opacity(0.78)
        case .club: return Theme.face.opacity(0.82)
        }
    }
}

#Preview("Golfer Figure") {
    GolferFigure(pose: .impact(Biomechanics()))
        .frame(height: 260)
        .padding()
}
