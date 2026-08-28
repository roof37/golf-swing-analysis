//
//  ResearchLibrary.swift
//  golf swing analysis
//
//  Content model + library for the Research tab — an interactive encyclopedia of
//  golf biomechanics. Topics are grouped into categories and cross-linked so a
//  user can learn a concept, see it, and jump to the Impact Lab to apply it.
//

import SwiftUI

// MARK: - Categories

enum ResearchCategory: String, CaseIterable, Identifiable {
    case ballFlight = "Ball Flight"
    case clubDelivery = "Club Delivery"
    case bodyMechanics = "Body Mechanics"
    case groundForces = "Ground Forces"
    case kinematicSequence = "Kinematic Sequence"
    case swingFaults = "Swing Faults"
    case equipment = "Equipment"
    case performance = "Performance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ballFlight: return "airplane.departure"
        case .clubDelivery: return "arrow.up.forward"
        case .bodyMechanics: return "figure.golf"
        case .groundForces: return "arrow.down.to.line"
        case .kinematicSequence: return "waveform.path"
        case .swingFaults: return "exclamationmark.triangle"
        case .equipment: return "wrench.and.screwdriver"
        case .performance: return "speedometer"
        }
    }

    var tint: Color {
        switch self {
        case .ballFlight: return .orange
        case .clubDelivery: return .blue
        case .bodyMechanics: return .purple
        case .groundForces: return .brown
        case .kinematicSequence: return .teal
        case .swingFaults: return .red
        case .equipment: return .gray
        case .performance: return .pink
        }
    }
}

// MARK: - Topic visual

enum TopicVisual {
    case symbol(String)
    case ballFlight(SwingModel)
    case body(Biomechanics)
    case kinematic(Biomechanics)
}

// MARK: - Topic

struct ResearchTopic: Identifiable {
    let id: String
    let title: String
    let category: ResearchCategory
    let overview: String
    let whyItMatters: String
    let mistakes: [String]
    let takeaways: [String]
    let related: [String]
    let visual: TopicVisual
    var applyInImpact: Bool = false
}

extension ResearchTopic {
    static func topics(in category: ResearchCategory) -> [ResearchTopic] {
        all.filter { $0.category == category }
    }

    static func by(id: String) -> ResearchTopic? {
        all.first { $0.id == id }
    }

    static func search(_ query: String) -> [ResearchTopic] {
        let q = query.lowercased()
        return all.filter { $0.title.lowercased().contains(q) || $0.overview.lowercased().contains(q) }
    }
}

// MARK: - Sample swings for visuals

private extension SwingModel {
    static var fade: SwingModel { var s = SwingModel(); s.faceAngle = 1; s.clubPath = -3; return s }
    static var draw: SwingModel { var s = SwingModel(); s.faceAngle = -1; s.clubPath = 3; return s }
    static var slice: SwingModel { var s = SwingModel(); s.faceAngle = 0; s.clubPath = -6; return s }
    static var openFace: SwingModel { var s = SwingModel(); s.faceAngle = 5; s.clubPath = 0; return s }
    static var pushDraw: SwingModel { var s = SwingModel(); s.faceAngle = 2; s.clubPath = 5; return s }
}

// MARK: - The library

extension ResearchTopic {
    static let all: [ResearchTopic] = [

        // — Ball Flight —
        ResearchTopic(
            id: "ball-flight-laws", title: "The Ball Flight Laws", category: .ballFlight,
            overview: "Modern launch data shows the ball starts mostly where the face points and curves based on the face's angle relative to the path.",
            whyItMatters: "Every shot you'll ever hit is explained by these two ideas — get them and you can diagnose any miss.",
            mistakes: ["Believing the ball starts where the club is swinging (it starts mostly on the face).",
                       "Trying to fix curve by changing only the path."],
            takeaways: ["Face ≈ start direction (about 85%).", "Face-to-path = curve."],
            related: ["start-direction", "spin-axis", "face-to-path"],
            visual: .ballFlight(.fade), applyInImpact: true),

        ResearchTopic(
            id: "start-direction", title: "Start Direction", category: .ballFlight,
            overview: "The initial direction the ball launches is controlled mostly by the clubface — roughly 85% face, 15% path for an iron.",
            whyItMatters: "If your shots start in the wrong direction, the face is the first place to look — not your aim or path.",
            mistakes: ["Aiming the body to fix a start-direction problem caused by the face."],
            takeaways: ["Open face → starts right.", "Closed face → starts left."],
            related: ["face-angle", "ball-flight-laws"],
            visual: .ballFlight(.openFace), applyInImpact: true),

        ResearchTopic(
            id: "spin-axis", title: "Curvature & Spin Axis", category: .ballFlight,
            overview: "A tilted spin axis makes the ball curve. The tilt comes from the face being open or closed relative to the path.",
            whyItMatters: "Curve isn't random — it's a direct, predictable result of face-to-path you can dial in.",
            mistakes: ["Confusing where the ball starts with which way it curves."],
            takeaways: ["Face open to path → curves right.", "Face closed to path → curves left."],
            related: ["face-to-path", "gear-effect"],
            visual: .ballFlight(.slice), applyInImpact: true),

        ResearchTopic(
            id: "nine-flights", title: "The Nine Ball Flights", category: .ballFlight,
            overview: "Combine three start directions (left, straight, right) with three curves to get the nine classic shot shapes.",
            whyItMatters: "Naming your shot (e.g. pull-fade) tells you exactly what the face and path did.",
            mistakes: ["Lumping all right misses together as 'a slice'."],
            takeaways: ["Start = face. Curve = face-to-path.", "Every miss maps to one of nine boxes."],
            related: ["start-direction", "spin-axis"],
            visual: .ballFlight(.pushDraw), applyInImpact: true),

        // — Club Delivery —
        ResearchTopic(
            id: "face-angle", title: "Club Face Angle", category: .clubDelivery,
            overview: "Where the face points at impact relative to the target. It's the single biggest factor in start direction.",
            whyItMatters: "Control the face and you control the start line — the foundation of every shot.",
            mistakes: ["Letting grip pressure or a flippy release rotate the face.",
                       "Ignoring the face and blaming the path for a start-line miss."],
            takeaways: ["Open = aimed right, closed = aimed left.", "A bowed lead wrist closes it; cupped opens it."],
            related: ["lead-wrist", "start-direction", "face-to-path"],
            visual: .ballFlight(.openFace), applyInImpact: true),

        ResearchTopic(
            id: "club-path", title: "Club Path", category: .clubDelivery,
            overview: "The horizontal direction the clubhead is travelling through impact — in-to-out (right) or out-to-in (left).",
            whyItMatters: "Path sets the floor for your curve and is the second half of the face-to-path equation.",
            mistakes: ["Swinging more left to stop a slice (steepens the out-to-in path)."],
            takeaways: ["In-to-out promotes a draw.", "Out-to-in promotes a fade/slice."],
            related: ["face-to-path", "over-the-top"],
            visual: .ballFlight(.draw), applyInImpact: true),

        ResearchTopic(
            id: "face-to-path", title: "Face-to-Path", category: .clubDelivery,
            overview: "The difference between face angle and path. This single number decides how much — and which way — the ball curves.",
            whyItMatters: "It's the clearest lever for shaping shots: match them for straight, separate them to curve.",
            mistakes: ["Thinking a square face always means a straight shot (it depends on the path)."],
            takeaways: ["Face = path → straight (a push or pull).", "Bigger gap → bigger curve."],
            related: ["spin-axis", "club-path", "face-angle"],
            visual: .ballFlight(.fade), applyInImpact: true),

        ResearchTopic(
            id: "angle-of-attack", title: "Angle of Attack", category: .clubDelivery,
            overview: "Whether the clubhead is moving down or up at impact. Down with irons, slightly up for a driver off a tee.",
            whyItMatters: "Attack angle drives compression, spin and launch — and pairs with path to set the true swing direction.",
            mistakes: ["Hitting down on the driver and losing distance.", "Trying to 'lift' irons instead of hitting down."],
            takeaways: ["Irons: hit down, ball-first.", "Driver: hit slightly up to add carry."],
            related: ["dynamic-loft", "spine-tilt"],
            visual: .symbol("arrow.down.forward")),

        ResearchTopic(
            id: "dynamic-loft", title: "Dynamic Loft", category: .clubDelivery,
            overview: "The actual loft delivered at impact, after shaft lean and face rotation — usually less than the club's stated loft.",
            whyItMatters: "Dynamic loft, with attack angle, sets launch angle and spin, which decide carry.",
            mistakes: ["Adding loft by flipping the hands instead of using forward shaft lean."],
            takeaways: ["Forward shaft lean de-lofts the club.", "Launch ≈ dynamic loft, broadly."],
            related: ["angle-of-attack", "smash-factor", "loft-lie"],
            visual: .symbol("triangle")),

        // — Body Mechanics —
        ResearchTopic(
            id: "hip-rotation", title: "Hip Rotation", category: .bodyMechanics,
            overview: "How far the pelvis has cleared toward the target by impact. Clearing the hips makes room for the arms and club.",
            whyItMatters: "Stalled hips force the path left and the hands to flip; cleared hips support speed and an in-to-out path.",
            mistakes: ["Stopping the pelvis through impact (the hands take over)."],
            takeaways: ["Keep the pelvis rotating through the ball.", "Cleared hips help the kinematic sequence."],
            related: ["x-factor", "club-path", "kinematic-sequence"],
            visual: .body(Biomechanics())),

        ResearchTopic(
            id: "x-factor", title: "Hip–Shoulder Separation", category: .bodyMechanics,
            overview: "The difference between hip and shoulder rotation. The hips leading the torso stores and releases energy.",
            whyItMatters: "Separation is the engine of the downswing — it sequences the body to deliver speed.",
            mistakes: ["Turning the shoulders and hips together (no separation, no power)."],
            takeaways: ["Let the hips lead the torso down.", "More separation, used well, means more speed."],
            related: ["kinematic-sequence", "hip-rotation"],
            visual: .body(Biomechanics())),

        ResearchTopic(
            id: "spine-tilt", title: "Spine Tilt", category: .bodyMechanics,
            overview: "Secondary axis tilt — leaning slightly away from the target at impact so the low point is correct.",
            whyItMatters: "Tilt sets your attack angle: too little is steep, too much hangs back and adds loft.",
            mistakes: ["Hanging way back to 'help' the ball up (thin/fat strikes)."],
            takeaways: ["A little tilt behind the ball helps a driver hit up.", "Too much tilt = weak, high contact."],
            related: ["angle-of-attack"],
            visual: .body({ var b = Biomechanics(); b.sideBend = 20; return b }())),

        ResearchTopic(
            id: "lead-wrist", title: "Lead Wrist", category: .bodyMechanics,
            overview: "Flexion (bowed) vs. extension (cupped) of the lead wrist controls the clubface through impact.",
            whyItMatters: "It's the most direct body link to the clubface — small wrist changes are big face changes.",
            mistakes: ["A last-second flip that throws the face wide open."],
            takeaways: ["Bowed → closes the face.", "Cupped → opens the face and adds loft."],
            related: ["face-angle"],
            visual: .body({ var b = Biomechanics(); b.leadWrist = -8; return b }())),

        // — Ground Forces —
        ResearchTopic(
            id: "vertical-force", title: "Vertical Force", category: .groundForces,
            overview: "Good players push hard into the ground and 'jump' to transfer energy up the chain into speed.",
            whyItMatters: "The ground is where speed starts — vertical force feeds the kinematic sequence.",
            mistakes: ["Staying flat-footed and only using the arms."],
            takeaways: ["Load into the ground, then push up.", "Vertical force precedes peak hand speed."],
            related: ["kinematic-sequence", "pressure-shift"],
            visual: .symbol("arrow.up.to.line")),

        ResearchTopic(
            id: "pressure-shift", title: "Pressure Shift", category: .groundForces,
            overview: "How weight (pressure) moves between the feet — back in the backswing, then strongly to the lead foot through impact.",
            whyItMatters: "A proper pressure shift puts you in front of the ball for ball-first contact and power.",
            mistakes: ["Hanging on the trail foot (reverse pivot, fat/thin)."],
            takeaways: ["Finish with pressure on the lead foot.", "Shift early in the downswing."],
            related: ["vertical-force", "spine-tilt"],
            visual: .symbol("figure.walk.motion")),

        // — Kinematic Sequence —
        ResearchTopic(
            id: "kinematic-sequence", title: "The Kinematic Sequence", category: .kinematicSequence,
            overview: "Efficient swings fire in order from the ground up: pelvis, then torso, then arms, then club — each peaking and handing off.",
            whyItMatters: "Sequence, not effort, creates effortless speed. Out of order, you leak power and cast.",
            mistakes: ["Starting the downswing with the arms and shoulders."],
            takeaways: ["Pelvis leads, club is last.", "Each segment peaks then slows to pass energy on."],
            related: ["x-factor", "lag", "vertical-force"],
            visual: .kinematic(Biomechanics())),

        ResearchTopic(
            id: "lag", title: "Lag & Release", category: .kinematicSequence,
            overview: "Lag is the angle held between the lead arm and the club in the downswing, released late for a whip through impact.",
            whyItMatters: "Holding lag and releasing it at the right time is a major speed and compression source.",
            mistakes: ["Casting — releasing the angle early from the top."],
            takeaways: ["Keep the club trailing the hands in transition.", "Release through impact, not before."],
            related: ["casting", "kinematic-sequence"],
            visual: .symbol("angle")),

        // — Swing Faults —
        ResearchTopic(
            id: "over-the-top", title: "Over the Top", category: .swingFaults,
            overview: "The shoulders spin open early, throwing the club out-to-in across the ball — the classic slice pattern.",
            whyItMatters: "It's the most common amateur fault and the root of the weak pull-slice.",
            mistakes: ["Aiming further left, which makes the out-to-in path worse."],
            takeaways: ["Let the lower body lead the transition.", "Shallow the club instead of throwing it out."],
            related: ["club-path", "casting", "x-factor"],
            visual: .ballFlight(.slice), applyInImpact: true),

        ResearchTopic(
            id: "early-extension", title: "Early Extension", category: .swingFaults,
            overview: "The hips thrust toward the ball in the downswing, standing up out of posture and crowding the arms.",
            whyItMatters: "It wrecks low-point control and often forces a flip or a block.",
            mistakes: ["Pushing the pelvis toward the ball instead of rotating it."],
            takeaways: ["Keep the pelvis back and rotating.", "Maintain your spine angle into impact."],
            related: ["spine-tilt", "hip-rotation"],
            visual: .symbol("figure.stand")),

        ResearchTopic(
            id: "casting", title: "Casting", category: .swingFaults,
            overview: "Releasing the wrist angle early from the top, so the club 'casts' out and speed peaks before impact.",
            whyItMatters: "Casting bleeds away lag, adds loft, and is a primary power leak.",
            mistakes: ["Trying to hit 'from the top' with the hands."],
            takeaways: ["Feel the club drop and trail the hands.", "Sequence from the ground to hold lag."],
            related: ["lag", "kinematic-sequence"],
            visual: .symbol("wind")),

        // — Equipment —
        ResearchTopic(
            id: "loft-lie", title: "Loft & Lie", category: .equipment,
            overview: "Static loft sets baseline launch; lie angle (how the sole sits) tilts the face left or right at impact.",
            whyItMatters: "Wrong lie angle pushes the face off-target even with a perfect swing.",
            mistakes: ["Ignoring lie angle when shots start consistently one way."],
            takeaways: ["Too upright → face points left; too flat → right.", "Get irons lie-fitted."],
            related: ["dynamic-loft", "face-angle"],
            visual: .symbol("ruler")),

        ResearchTopic(
            id: "gear-effect", title: "Gear Effect", category: .equipment,
            overview: "Off-center strikes make the face twist, imparting corrective spin — toe hits draw, heel hits fade.",
            whyItMatters: "It explains why mishits curve, and why driver faces are curved (bulge and roll).",
            mistakes: ["Blaming path/face for curve that's actually a strike-location issue."],
            takeaways: ["Toe strike → draw spin.", "Heel strike → fade spin."],
            related: ["spin-axis"],
            visual: .symbol("circle.grid.cross")),

        // — Performance —
        ResearchTopic(
            id: "smash-factor", title: "Smash Factor", category: .performance,
            overview: "Ball speed divided by clubhead speed — a measure of strike efficiency. Center hits maximize it.",
            whyItMatters: "Two players at the same speed can have very different distance based on smash.",
            mistakes: ["Chasing speed while ignoring center contact."],
            takeaways: ["Center strike = higher smash = more ball speed.", "Driver tops out near 1.50."],
            related: ["gear-effect", "clubhead-speed", "dynamic-loft"],
            visual: .symbol("speedometer")),

        ResearchTopic(
            id: "clubhead-speed", title: "Clubhead Speed", category: .performance,
            overview: "How fast the head is moving at impact — the biggest raw driver of potential distance.",
            whyItMatters: "Speed is trainable and, paired with center contact, is the main lever for carry.",
            mistakes: ["Adding speed at the cost of strike quality."],
            takeaways: ["Sequence and ground force build speed.", "Speed only helps if you find the center."],
            related: ["kinematic-sequence", "smash-factor"],
            visual: .symbol("gauge.high"))
    ]
}
