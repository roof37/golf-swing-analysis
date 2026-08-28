//
//  ResearchView.swift
//  golf swing analysis
//
//  Research tab — an interactive biomechanics library. Browse categories or
//  search topics; each topic is a clean card with an overview, a visual, why it
//  matters, common mistakes, coaching takeaways, related topics, and a jump into
//  the Impact Lab.
//

import SwiftUI

struct ResearchView: View {
    @Bindable var lab: SwingLab
    @State private var query = ""
    @State private var selectedCategory: ResearchCategory?

    private var filteredTopics: [ResearchTopic] {
        ResearchTopic.all.filter { topic in
            let matchesCategory = selectedCategory == nil || topic.category == selectedCategory
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = trimmedQuery.isEmpty
                || topic.title.lowercased().contains(trimmedQuery)
                || topic.overview.lowercased().contains(trimmedQuery)
                || topic.takeaways.joined(separator: " ").lowercased().contains(trimmedQuery)
            return matchesCategory && matchesQuery
        }
    }

    private var featuredTopic: ResearchTopic {
        if abs(lab.swing.faceToPath) > 2.5 {
            return ResearchTopic.by(id: "face-to-path") ?? ResearchTopic.all[0]
        }
        if abs(lab.swing.faceAngle) > 2.5 {
            return ResearchTopic.by(id: "start-direction") ?? ResearchTopic.all[0]
        }
        if abs(lab.swing.clubPath) > 2.5 {
            return ResearchTopic.by(id: "club-path") ?? ResearchTopic.all[0]
        }
        return ResearchTopic.by(id: "ball-flight-laws") ?? ResearchTopic.all[0]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.gap) {
                    libraryHeader
                    featuredCard
                    categoryRail
                    topicList
                }
                .padding()
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search ball flight, body, faults")
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Research Library")
                        .font(.title2.bold())
                    Text("Find the concept behind a miss, body pattern, or ball flight change.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.path, in: RoundedRectangle(cornerRadius: Theme.insetRadius))
            }

            HStack(spacing: 8) {
                libraryStat("Topics", "\(ResearchTopic.all.count)")
                libraryStat("Categories", "\(ResearchCategory.allCases.count)")
                libraryStat("Showing", "\(filteredTopics.count)")
            }
        }
        .card()
    }

    private var featuredCard: some View {
        NavigationLink {
            TopicView(topic: featuredTopic, lab: lab)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Label("Recommended From Your Shot", systemImage: "sparkle.magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: featuredTopic.category.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(featuredTopic.category.tint, in: RoundedRectangle(cornerRadius: Theme.insetRadius))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(featuredTopic.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(featuredTopic.overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: Theme.innerGap) {
            SectionHeader("Browse", systemImage: "square.grid.2x2")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(title: "All", icon: "tray.full", tint: Theme.path, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(ResearchCategory.allCases) { category in
                        categoryChip(
                            title: category.rawValue,
                            icon: category.icon,
                            tint: category.tint,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .card()
    }

    @ViewBuilder
    private var topicList: some View {
        if filteredTopics.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, 32)
        } else {
            VStack(alignment: .leading, spacing: Theme.innerGap) {
                SectionHeader(topicListTitle, systemImage: "text.book.closed")

                ForEach(filteredTopics) { topic in
                    NavigationLink {
                        TopicView(topic: topic, lab: lab)
                    } label: {
                        TopicRow(topic: topic)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var topicListTitle: String {
        if let selectedCategory { return selectedCategory.rawValue }
        return query.isEmpty ? "All Topics" : "Search Results"
    }

    private func libraryStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func categoryChip(title: String, icon: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : tint)
                .background(isSelected ? tint : tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category screen

struct ResearchCategoryView: View {
    let category: ResearchCategory
    @Bindable var lab: SwingLab

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.innerGap) {
                ForEach(ResearchTopic.topics(in: category)) { topic in
                    NavigationLink {
                        TopicView(topic: topic, lab: lab)
                    } label: {
                        TopicRow(topic: topic)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Topic row

struct TopicRow: View {
    let topic: ResearchTopic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: topic.category.icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(topic.category.tint, in: RoundedRectangle(cornerRadius: Theme.insetRadius))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(topic.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(topic.overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(topic.category.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(topic.category.tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(topic.category.tint)

                    if topic.applyInImpact {
                        Label("Impact Lab", systemImage: "arrow.right.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.path)
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Topic detail

struct TopicView: View {
    let topic: ResearchTopic
    @Bindable var lab: SwingLab

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gap) {
                topicHero
                visualCard
                diagnosisCard
                causeEffectCard

                if !topic.mistakes.isEmpty {
                    mistakeCard
                }

                takeawayCard
                impactLabButton
                relatedCard
            }
            .padding()
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topicHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: topic.category.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(topic.category.tint, in: RoundedRectangle(cornerRadius: Theme.insetRadius))

                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(topic.title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(topic.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var visualCard: some View {
        CardSection(visualTitle, systemImage: "eye") {
            topicVisual
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(visualBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Text(visualCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var diagnosisCard: some View {
        CardSection("How To Read It", systemImage: "stethoscope") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                diagnosisTile("Primary clue", primaryClue, "magnifyingglass")
                diagnosisTile("Ball flight", likelyBallFlight, "scope")
                diagnosisTile("Body pattern", bodyPattern, "figure.golf")
                diagnosisTile("Best next check", nextCheck, "checkmark.circle")
            }
        }
    }

    private var causeEffectCard: some View {
        CardSection("Cause And Effect", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 10) {
                flowRow("Cause", causeText, Theme.warn)
                flowConnector
                flowRow("Result", effectText, Theme.path)
                flowConnector
                flowRow("Fix direction", fixText, Theme.good)
            }
        }
    }

    private var mistakeCard: some View {
        CardSection("Common Trap", systemImage: "exclamationmark.triangle.fill") {
            bullets(topic.mistakes, color: Theme.bad, symbol: "xmark.circle.fill")
        }
    }

    private var takeawayCard: some View {
        CardSection("Coach Notes", systemImage: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text(topic.whyItMatters)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                bullets(topic.takeaways, color: Theme.good, symbol: "checkmark.circle.fill")
            }
        }
    }

    @ViewBuilder
    private var impactLabButton: some View {
        if topic.applyInImpact {
            Button {
                lab.selectedTab = .impact
            } label: {
                Label("Try this in Shot Lab", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var relatedCard: some View {
        if !relatedTopics.isEmpty {
            CardSection("Keep Learning", systemImage: "link") {
                VStack(spacing: 8) {
                    ForEach(relatedTopics) { rel in
                        NavigationLink {
                            TopicView(topic: rel, lab: lab)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: rel.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(rel.category.tint, in: RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rel.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(rel.category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var relatedTopics: [ResearchTopic] {
        topic.related.compactMap { ResearchTopic.by(id: $0) }
    }

    private var visualBackground: Color {
        switch topic.visual {
        case .ballFlight, .body: return Theme.field
        default: return Theme.card
        }
    }

    private var visualTitle: String {
        switch topic.visual {
        case .ballFlight: return "Ball Flight Pattern"
        case .body: return "Body Pattern"
        case .kinematic: return "Sequence Pattern"
        case .symbol: return "Concept Snapshot"
        }
    }

    private var visualCaption: String {
        switch topic.visual {
        case .ballFlight: return "Use the shot shape as the visible symptom, then work backward to face, path, and body pattern."
        case .body: return "The body view highlights the position most connected to this concept."
        case .kinematic: return "The sequence view shows whether speed is transferring cleanly from body to club."
        case .symbol: return "This concept affects delivery even when it does not have one single ball-flight shape."
        }
    }

    @ViewBuilder
    private var topicVisual: some View {
        switch topic.visual {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 60))
                .foregroundStyle(topic.category.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ballFlight(let sample):
            RangeView(swing: sample)
        case .body(let bio):
            GolferFigure(pose: .impact(bio))
        case .kinematic(let bio):
            KinematicSequenceView(segments: bio.sequence).padding()
        }
    }

    private func diagnosisTile(_ label: String, _ value: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(topic.category.tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: Theme.insetRadius))
    }

    private func flowRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 92)
                .padding(.vertical, 6)
                .background(color, in: Capsule())
            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var flowConnector: some View {
        Image(systemName: "arrow.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 40)
    }

    private func bullets(_ items: [String], color: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var primaryClue: String {
        switch topic.category {
        case .ballFlight: return "Start and curve"
        case .clubDelivery: return "Impact numbers"
        case .bodyMechanics: return "Position at impact"
        case .groundForces: return "Pressure shift"
        case .kinematicSequence: return "Timing order"
        case .swingFaults: return "Repeatable miss"
        case .equipment: return "Fit or contact"
        case .performance: return "Speed and control"
        }
    }

    private var likelyBallFlight: String {
        switch topic.id {
        case "over-the-top": return "Pull-slice"
        case "club-path": return "Draw or fade"
        case "face-angle", "start-direction": return "Start-line miss"
        case "spin-axis", "face-to-path": return "Curve miss"
        case "early-extension": return "Block or flip"
        case "casting": return "Weak high fade"
        default: return topic.category == .ballFlight ? "Shot shape" : "Depends on delivery"
        }
    }

    private var bodyPattern: String {
        switch topic.id {
        case "over-the-top": return "Shoulders fire early"
        case "early-extension": return "Hips move toward ball"
        case "casting": return "Angles release early"
        case "hip-rotation": return "Pelvis clears"
        case "x-factor": return "Hips lead torso"
        case "spine-tilt": return "Axis behind ball"
        default: return topic.category == .bodyMechanics ? "Main driver" : "Supporting factor"
        }
    }

    private var nextCheck: String {
        switch topic.id {
        case "over-the-top", "club-path": return "Path direction"
        case "face-angle", "start-direction": return "Face angle"
        case "spin-axis", "face-to-path": return "Face-to-path"
        case "kinematic-sequence", "x-factor": return "Sequence timing"
        default: return "Current swing"
        }
    }

    private var causeText: String {
        switch topic.id {
        case "over-the-top": return "The upper body starts the downswing first, throwing the club outside the target line."
        case "early-extension": return "The pelvis moves toward the ball, taking space away from the arms."
        case "casting": return "The wrists release early, so the clubhead passes energy before impact."
        case "face-to-path": return "The face and path separate instead of matching the intended shape."
        case "start-direction": return "The face is pointed away from the target when the ball leaves the club."
        case "club-path": return "The clubhead travels across the target line through impact."
        default: return topic.overview
        }
    }

    private var effectText: String {
        switch topic.id {
        case "over-the-top": return "The ball often starts left, then curves right because the path is left of the face."
        case "early-extension": return "Contact gets inconsistent and the hands compensate with blocks, hooks, or thin strikes."
        case "casting": return "Speed leaks early, launch gets weak, and compression drops."
        case "face-to-path": return "A bigger face-to-path gap creates more curve."
        case "start-direction": return "The start line follows the face more than the swing direction."
        case "club-path": return "Path creates the curve tendency when compared against the face."
        default: return topic.whyItMatters
        }
    }

    private var fixText: String {
        switch topic.id {
        case "over-the-top": return "Let the lower body lead, keep the trail shoulder from firing out, and feel the club shallow behind you."
        case "early-extension": return "Keep posture while the pelvis turns, then give the arms room to pass."
        case "casting": return "Keep the handle moving and let the club release later, closer to impact."
        case "face-to-path": return "Match face and path for straight shots; separate them intentionally for curves."
        case "start-direction": return "Fix the face first, then tune path."
        case "club-path": return "Adjust the direction the club travels through impact, then match the face to it."
        default: return topic.takeaways.first ?? "Use the related drills and compare the result in Shot Lab."
        }
    }
}
