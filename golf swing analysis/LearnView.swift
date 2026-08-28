//
//  LearnView.swift
//  golf swing analysis
//
//  Learn tab: a short, ordered curriculum. Each lesson explains one idea in plain
//  language with a live mini-demo the user can play with (the irrelevant controls
//  are locked so each lesson isolates a single concept). The full
//  Body→Delivery→Impact→Flight breakdown of the current swing lives here too.
//

import SwiftUI

// MARK: - Lesson model

/// Starting state + which controls are adjustable for a lesson's demo.
struct LessonDemo {
    var face: Double = 0
    var path: Double = 0
    var lockFace: Bool = false
    var lockPath: Bool = false
}

struct LearnLesson: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let intro: String
    let points: [String]
    let tip: String
    let demo: LessonDemo
}

extension LearnLesson {
    static let library: [LearnLesson] = [
        LearnLesson(
            title: "The Two Controls",
            icon: "scope",
            intro: "Almost every shot is shaped by just two things at impact: where the clubface points, and the direction the club is moving.",
            points: [
                "The face is mostly where the ball starts.",
                "The path is where the club is swinging.",
                "The gap between them is what makes the ball curve."
            ],
            tip: "Drag both sliders and watch the start direction and the curve change.",
            demo: LessonDemo(face: 0, path: 0)
        ),
        LearnLesson(
            title: "The Clubface",
            icon: "circle.lefthalf.filled",
            intro: "The clubface controls where the ball starts — roughly 85% of the start direction comes from the face.",
            points: [
                "Open face (right) → the ball starts right.",
                "Closed face (left) → the ball starts left.",
                "Square face → it starts at the target."
            ],
            tip: "The path is locked square. Move only the face and watch the ball start where the face points.",
            demo: LessonDemo(face: 0, path: 0, lockPath: true)
        ),
        LearnLesson(
            title: "The Club Path",
            icon: "arrow.up.forward",
            intro: "The path is the direction the clubhead is travelling through impact.",
            points: [
                "In-to-out (right of target) tends to curve the ball left.",
                "Out-to-in (left of target) tends to curve it right.",
                "With a square face, the ball starts near the path and curves away from it."
            ],
            tip: "The face is locked square. Move the path and watch the curve appear.",
            demo: LessonDemo(face: 0, path: 0, lockFace: true)
        ),
        LearnLesson(
            title: "Why the Ball Curves",
            icon: "arrow.triangle.turn.up.right.diamond",
            intro: "Curve comes from the difference between the face and the path — what coaches call 'face-to-path'.",
            points: [
                "Face open to the path → curves right (fade/slice).",
                "Face closed to the path → curves left (draw/hook).",
                "Face matching the path → dead straight (a pull or push with no curve)."
            ],
            tip: "Set the face and path to the SAME number — the ball flies straight. Spread them apart to curve it.",
            demo: LessonDemo(face: 3, path: -3)
        ),
        LearnLesson(
            title: "Why You Slice",
            icon: "exclamationmark.triangle",
            intro: "A slice is an out-to-in path with the face open to that path — the most common amateur miss.",
            points: [
                "The path swings left of target (out-to-in).",
                "The face is open relative to the path.",
                "The ball starts left-ish and curves hard to the right."
            ],
            tip: "Try to straighten it: bring the face square to the path, or swing the path more in-to-out.",
            demo: LessonDemo(face: -1, path: -6)
        ),
        LearnLesson(
            title: "Hit a Draw",
            icon: "arrow.uturn.left",
            intro: "A draw curves gently right-to-left: an in-to-out path with the face just closed to that path.",
            points: [
                "Swing the path a few degrees in-to-out (right).",
                "Aim the face at the target — closed to the path, but open to it would be a push.",
                "The ball starts right of target and curves back."
            ],
            tip: "Set the path to about +4 and the face to about +1, and watch a draw appear.",
            demo: LessonDemo(face: 0, path: 0)
        )
    ]
}

// MARK: - Learn menu

struct LearnView: View {
    @Bindable var lab: SwingLab

    private var starterLessons: [LearnLesson] { Array(LearnLesson.library.prefix(4)) }
    private var fixLessons: [LearnLesson] { Array(LearnLesson.library.dropFirst(4)) }

    var body: some View {
        Screen("Lessons", titleDisplayMode: .inline) {
            currentSwingCard

            if let first = LearnLesson.library.first {
                featuredLesson(first)
            }

            lessonGroup("Start Here", subtitle: "Face, path, start line, and curve.", lessons: starterLessons)
            lessonGroup("Fix Common Shots", subtitle: "Use the laws to understand misses and shapes.", lessons: fixLessons)
        }
    }

    private var currentSwingCard: some View {
        CardSection("Your Swing", systemImage: "link.circle") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Current result")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(lab.swing.shotName)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                    Image(systemName: lab.deliveryMatchesBody ? "link.circle.fill" : "link.badge.plus")
                        .font(.title3)
                        .foregroundStyle(lab.deliveryMatchesBody ? Theme.good : Theme.warn)
                }

                Text(lab.deliveryMatchesBody ? "Body, delivery, and flight are linked." : "Your Shot Lab delivery was adjusted manually. Link it to the Swing Lab body to see the full chain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    SwingBreakdownView(lab: lab)
                } label: {
                    Label("Break down why", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private func featuredLesson(_ lesson: LearnLesson) -> some View {
        NavigationLink {
            LessonDetailView(lesson: lesson)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: lesson.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.tint, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Featured Lesson")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(lesson.title)
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(lesson.intro)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func lessonGroup(_ title: String, subtitle: String, lessons: [LearnLesson]) -> some View {
        CardSection(title, systemImage: "book.pages") {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                    NavigationLink {
                        LessonDetailView(lesson: lesson)
                    } label: {
                        lessonRow(number: lessonNumber(for: lesson, fallback: index + 1), lesson: lesson)
                    }
                    .buttonStyle(.plain)

                    if lesson.id != lessons.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func lessonRow(number: Int, lesson: LearnLesson) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title).font(.subheadline.weight(.semibold))
                Text(lesson.intro)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func lessonNumber(for lesson: LearnLesson, fallback: Int) -> Int {
        LearnLesson.library.firstIndex { $0.id == lesson.id }.map { $0 + 1 } ?? fallback
    }
}

// MARK: - Lesson detail (concept + live demo)

struct LessonDetailView: View {
    let lesson: LearnLesson
    @State private var demoSwing: SwingModel

    init(lesson: LearnLesson) {
        self.lesson = lesson
        var s = SwingModel()
        s.faceAngle = lesson.demo.face
        s.clubPath = lesson.demo.path
        _demoSwing = State(initialValue: s)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                lessonHeader
                liveDemoCard
                controlsCard
                keyIdeasCard
                practiceCueCard
            }
            .padding()
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lessonHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lesson", systemImage: lesson.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(lesson.title)
                .font(.title2.bold())

            Text(lesson.intro)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var liveDemoCard: some View {
        CardSection("Live Ball Flight", systemImage: "scope") {
            RangeView(swing: demoSwing)
                .fieldPanel(height: 220)

            resultBar
        }
    }

    private var controlsCard: some View {
        CardSection("Try The Move", systemImage: "slider.horizontal.3") {
            demoControls
        }
    }

    private var keyIdeasCard: some View {
        CardSection("What To Notice", systemImage: "checkmark.seal") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lesson.points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 10) {
                        lessonNumber(index + 1)
                        Text(point)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var practiceCueCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.title3)
                .foregroundStyle(Theme.face)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Practice Cue")
                    .font(.headline)
                Text(lesson.tip)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var resultBar: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            stat("Shot", demoSwing.shotName, systemImage: "target")
            stat("Start", startText, systemImage: "arrow.up.right")
            stat("Curve", curveText, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        }
    }

    private func stat(_ label: String, _ value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    @ViewBuilder
    private var demoControls: some View {
        VStack(spacing: 14) {
            if lesson.demo.lockFace {
                lockedRow("Club Face", "square (locked)", systemImage: "lock.fill")
            } else {
                ParameterSlider(
                    title: "Club Face",
                    value: $demoSwing.faceAngle,
                    range: -10...10,
                    unit: "°",
                    lowLabel: "Closed",
                    highLabel: "Open",
                    info: "Club face has the biggest effect on where the ball starts. A closed face starts the ball left for a right-handed golfer; an open face starts it right."
                )
            }

            if lesson.demo.lockPath {
                lockedRow("Club Path", "square (locked)", systemImage: "lock.fill")
            } else {
                ParameterSlider(
                    title: "Club Path",
                    value: $demoSwing.clubPath,
                    range: -10...10,
                    unit: "°",
                    lowLabel: "Out-to-in",
                    highLabel: "In-to-out",
                    info: "Club path is the direction the clubhead travels through impact. Path compared with face angle creates most of the curve."
                )
            }
        }
    }

    private func lockedRow(_ title: String, _ value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func lessonNumber(_ number: Int) -> some View {
        Text("\(number)")
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Theme.good)
            .clipShape(Circle())
    }

    private var startText: String {
        let d = demoSwing.launchDirection
        if abs(d) < 1 { return "On line" }
        return String(format: "%.0f° %@", abs(d), d > 0 ? "R" : "L")
    }

    private var curveText: String {
        let curve = (demoSwing.spinAxis / 45) * max(demoSwing.carryDistance, 1) * 0.5
        if abs(curve) < 1 { return "Straight" }
        return String(format: "%.0f yd %@", abs(curve), curve > 0 ? "R" : "L")
    }
}

// MARK: - Current-swing breakdown (Body → Delivery → Impact → Flight)

struct SwingBreakdownView: View {
    @Bindable var lab: SwingLab

    private var swing: SwingModel { lab.swing }
    private var explanation: SwingExplanation {
        SwingExplanation(swing: lab.swing, bio: lab.biomechanics)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                syncBanner

                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    StageCard(stage: stage)
                    if index < stages.count - 1 {
                        ChainConnector()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Why This Shot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var syncBanner: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: lab.deliveryMatchesBody ? "link.circle.fill" : "link.badge.plus")
                    .foregroundStyle(lab.deliveryMatchesBody ? .green : .orange)
                Text(lab.deliveryMatchesBody
                     ? "Chain is linked: the delivery matches your body."
                     : "Delivery was set manually — it doesn't match your body positions.")
                    .font(.caption)
                Spacer()
            }
            if !lab.deliveryMatchesBody {
                Button {
                    withAnimation { lab.sendBodyToImpact() }
                } label: {
                    Label("Link delivery to body", systemImage: "arrow.triangle.merge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 4)
    }

    private var stages: [Stage] {
        [
            Stage(
                title: "Body",
                systemImage: "figure.golf",
                tint: .purple,
                metrics: [
                    ("Thorax", deg(lab.biomechanics.thoraxRotation)),
                    ("Pelvis", deg(lab.biomechanics.pelvisRotation)),
                    ("Pressure", "\(Int(lab.biomechanics.leadPressure))% lead"),
                    ("Lead Wrist", deg(lab.biomechanics.leadWrist)),
                    ("Sequence", "\(Int(lab.biomechanics.transitionSequence))%")
                ],
                why: explanation.bodyToDelivery,
                whyTitle: "How the body shapes delivery"
            ),
            Stage(
                title: "Club Delivery",
                systemImage: "arrow.up.forward",
                tint: .blue,
                metrics: [
                    ("Path", deg(swing.clubPath)),
                    ("Face", deg(swing.faceAngle)),
                    ("Attack", deg(swing.angleOfAttack)),
                    ("Loft", deg(swing.dynamicLoft)),
                    ("Shaft Lean", deg(swing.shaftLean)),
                    ("Speed", "\(Int(swing.swingSpeed)) mph")
                ],
                why: explanation.deliveryToImpact,
                whyTitle: "How delivery sets up impact"
            ),
            Stage(
                title: "Impact",
                systemImage: "burst.fill",
                tint: .red,
                metrics: [
                    ("Face-to-Path", deg(swing.faceToPath)),
                    ("Spin Loft", deg(swing.spinLoft)),
                    ("Strike", String(format: "%+.0f mm", swing.strikeOffset)),
                    ("Backspin", "\(Int(swing.backSpin)) rpm"),
                    ("Ball Speed", "\(Int(swing.ballSpeed)) mph"),
                    ("Smash", String(format: "%.2f", swing.smashFactor))
                ],
                why: explanation.impactToFlight,
                whyTitle: "How impact creates the flight"
            ),
            Stage(
                title: "Ball Flight",
                systemImage: "flag.fill",
                tint: .green,
                metrics: [
                    ("Shot", swing.shotName),
                    ("Launch Dir", deg(swing.launchDirection)),
                    ("Spin Axis", deg(swing.spinAxis)),
                    ("Carry", "\(Int(swing.carryDistance)) yd"),
                    ("Apex", "\(Int(swing.peakHeight)) ft"),
                    ("Rollout", "\(Int(swing.rollout)) yd")
                ],
                why: [],
                whyTitle: ""
            )
        ]
    }

    private func deg(_ v: Double) -> String { String(format: "%+.1f°", v) }
}

// MARK: - Stage model & card

struct Stage {
    let title: String
    let systemImage: String
    let tint: Color
    let metrics: [(label: String, value: String)]
    let why: [String]
    let whyTitle: String
}

struct StageCard: View {
    let stage: Stage

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: stage.systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(stage.tint, in: Circle())
                Text(stage.title).font(.title3.bold())
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(stage.metrics, id: \.label) { metric in
                    VStack(spacing: 2) {
                        Text(metric.value).font(.subheadline.bold().monospacedDigit())
                        Text(metric.label).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if !stage.why.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stage.whyTitle.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(stage.tint)
                    ForEach(stage.why, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(line)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(stage.tint.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ChainConnector: View {
    var body: some View {
        Image(systemName: "chevron.compact.down")
            .font(.title2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }
}
