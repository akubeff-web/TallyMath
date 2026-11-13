import SwiftUI
import MathCore

/// Вкладка «Курс»: все темы 5–8 классов сразу, с фильтром по классу.
struct CourseView: View {
    @Environment(AppModel.self) private var model
    @State private var grade: Grade?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Класс", selection: $grade) {
                    Text("Все").tag(Grade?.none)
                    ForEach(Grade.allCases, id: \.self) { g in Text("\(g.rawValue)").tag(Grade?.some(g)) }
                }
                .pickerStyle(.segmented)
                ForEach(grades, id: \.self) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: g.title)
                        ForEach(Course.sections(in: g)) { section in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(section.title).font(.caption).foregroundStyle(Color.sub).padding(.bottom, 6)
                                ForEach(section.topics) { t in
                                    NavigationLink(value: Route.topic(t.id)) { row(t) }
                                        .buttonStyle(.plain)
                                    if t.id != section.topics.last?.id { Divider().overlay(Color.hairline) }
                                }
                            }
                            .contentCard(radius: 22, padding: 14)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .navigationTitle("Курс")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.custom) { Label("Свой пример", systemImage: "plus") }
            }
        }
    }

    private var grades: [Grade] { grade.map { [$0] } ?? Grade.allCases }

    private func row(_ t: TopicDef) -> some View {
        let p = model.progress.progress(t.id)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                if let v = model.why[t.id]?.verdict {
                    Text(v).font(.caption2).foregroundStyle(Color.sub)
                }
            }
            Spacer()
            if model.progress.dueReviews(day: model.today).contains(t.id) { Tag(text: "повтор", dashed: false) }
            AccuracyBar(fraction: Double(p.accuracyPercent ?? 0) / 100).frame(width: 40)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.faint)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Карточка темы: урок, тренировка, «Решить самому», повторение и «Зачем это нужно».
struct TopicCardView: View {
    let topicID: String
    var whyExpanded = true
    @Environment(AppModel.self) private var model
    @State private var expanded = true

    var body: some View {
        let topic = Course.topic(topicID)
        let p = model.progress.progress(topicID)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let topic {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title).font(.title.weight(.bold))
                            Text("\(topic.grade.title) · \(topic.section)" + (p.accuracyPercent.map { " · точность \($0)%" } ?? ""))
                                .font(.subheadline).foregroundStyle(Color.sub)
                        }
                        Spacer()
                        BitView(mood: .idle, size: 60)
                    }
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            NavigationLink(value: Route.lesson(topicID)) {
                                Text("Урок").font(.subheadline.weight(.semibold)).foregroundStyle(Color.inverse)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.ink)
                            NavigationLink(value: Route.training(SessionRequest(topicIDs: [topicID], title: topic.title))) {
                                Text("Тренировать").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            NavigationLink(value: Route.solve(topic.example(seed: UInt64(model.today)))) {
                                Text("Решить самому").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.glass)
                        }
                        .controlSize(.large)
                    }
                    if let review = p.review { reviewCard(review) }
                    WhySection(entry: model.why[topicID], expanded: $expanded)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { expanded = whyExpanded }
    }

    private func reviewCard(_ r: ReviewState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Повторение").font(.headline)
                Spacer()
                let days = r.dueDay - model.today
                Label(days <= 0 ? "сегодня" : "через \(days) д", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.3))
            }
            ReviewTimeline(done: r.stage)
            Text("Интервалы растут: 1, 3, 7, 14, 30 дней. Две ошибки и больше из 5 — интервал снова короткий.")
                .font(.footnote).foregroundStyle(Color.sub)
            if r.dueDay <= model.today {
                NavigationLink(value: Route.training(SessionRequest(topicIDs: [topicID], count: 5, isReview: true, title: "Повторение"))) {
                    Label("Повторить · 5 примеров", systemImage: "arrow.clockwise")
                        .font(.headline).foregroundStyle(Color.inverse).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.ink)
            }
        }
        .contentCard()
    }
}

/// Блок «Зачем это нужно»: честная оценка, пример на Swift и пересказ реальных обсуждений со ссылками.
struct WhySection: View {
    let entry: WhyEntry?
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
            } label: {
                HStack {
                    Text("Зачем это нужно").font(.headline).foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Свернуть" : "Развернуть")
            if expanded {
                if let entry { content(entry) } else {
                    Text("Для этой темы блок ещё не собран.").font(.subheadline).foregroundStyle(Color.sub)
                }
            }
        }
        .contentCard()
    }

    @ViewBuilder
    private func content(_ e: WhyEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(e.verdict.prefix(1).uppercased() + e.verdict.dropFirst())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(e.verdict == "нужно" ? Color.inverse : Color.ink)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(e.verdict == "нужно" ? Color.ink : .clear))
                .overlay(Capsule().strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 1.4, dash: e.verdict == "можно пропустить" ? [4, 3] : [])))
                .fixedSize()
            Text(e.reason).font(.subheadline).foregroundStyle(Color.sub)
        }
        if let prog = e.programming {
            SectionLabel(text: "В программировании")
            Text(prog).font(.subheadline)
        }
        if let code = e.swift, !code.isEmpty {
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ink.opacity(0.06)))
                .accessibilityLabel("Пример кода на Swift")
        }
        if let life = e.life {
            SectionLabel(text: "В жизни")
            Text(life).font(.subheadline)
        }
        SectionLabel(text: "Что говорят люди")
        if e.sources.isEmpty {
            Text("Подтверждённого примера нет.").font(.subheadline).foregroundStyle(Color.sub)
        }
        ForEach(e.sources, id: \.url) { s in
            if let url = URL(string: s.url) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(s.site) · проверено \(s.checked)").font(.caption.weight(.bold)).foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Color.ink)
                        }
                        Text(s.summary).font(.footnote).foregroundStyle(Color.sub).multilineTextAlignment(.leading)
                    }
                }
                Divider().overlay(Color.hairline)
            }
        }
        Text("Мнения людей субъективны, это не истина.")
            .font(.caption2).foregroundStyle(Color.sub).frame(maxWidth: .infinity)
    }
}
