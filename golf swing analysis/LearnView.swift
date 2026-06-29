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

    var body: some View {
        NavigationStack {
            List {
                Section("Lessons") {
                    ForEach(Array(LearnLesson.library.enumerated()), id: \.element.id) { index, lesson in
                        NavigationLink {
                            LessonDetailView(lesson: lesson)
                        } label: {
                            lessonRow(number: index + 1, lesson: lesson)
                        }
                    }
                }

                Section("Your swing") {
                    NavigationLink {
                        SwingBreakdownView(lab: lab)
                    } label: {
                        Label("Break down my current swing", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("Learn")
        }
    }

    private func lessonRow(number: Int, lesson: LearnLesson) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title).font(.headline)
                Text(lesson.intro)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
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
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.intro)
                    .font(.body)

                // Live demo.
                RangeView(swing: demoSwing)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGreen).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                resultBar
                demoControls

                // Key points.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lesson.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            Text(point)
                        }
                        .font(.subheadline)
                    }
                }

                // Try-it tip.
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hand.draw").foregroundStyle(.orange)
                    Text(lesson.tip).font(.subheadline.weight(.medium))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultBar: some View {
        HStack(spacing: 0) {
            stat("Shot", demoSwing.shotName)
            Divider().frame(height: 30)
            stat("Start", startText)
            Divider().frame(height: 30)
            stat("Curve", curveText)
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var demoControls: some View {
        VStack(spacing: 12) {
            if lesson.demo.lockFace {
                lockedRow("Club Face", "square (locked)")
            } else {
                ParameterSlider(title: "Club Face", value: $demoSwing.faceAngle,
                                range: -10...10, unit: "°", lowLabel: "Closed", highLabel: "Open")
            }
            if lesson.demo.lockPath {
                lockedRow("Club Path", "square (locked)")
            } else {
                ParameterSlider(title: "Club Path", value: $demoSwing.clubPath,
                                range: -10...10, unit: "°", lowLabel: "Out-to-in", highLabel: "In-to-out")
            }
        }
    }

    private func lockedRow(_ title: String, _ value: String) -> some View {
        HStack {
            Image(systemName: "lock.fill").font(.caption2)
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text(value).font(.caption)
        }
        .foregroundStyle(.secondary)
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
                    ("Shoulders", deg(lab.biomechanics.shoulderRotation)),
                    ("Hips", deg(lab.biomechanics.hipRotation)),
                    ("Weight", "\(Int(lab.biomechanics.weightShift))% lead"),
                    ("Lead Wrist", deg(lab.biomechanics.leadWrist)),
                    ("Sequence", "\(Int(lab.biomechanics.sequenceEfficiency))%")
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
