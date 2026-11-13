import SwiftUI
import MathCore

/// Главная: Bit, режим, столбики или темы, краткая статистика и «Начать».
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                bitCard
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Режим")
                    Picker("Режим", selection: $model.mode) {
                        ForEach(TrainingMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                switch model.mode {
                case .multiplication: columnsPicker
                case .fractions: topicsList
                case .mixed: mixedNote
                }
                if let request = startRequest {
                    NavigationLink(value: Route.training(request)) {
                        Label("Начать · 10 примеров", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(Color.inverse)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.ink)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Tally")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.custom) {
                    Label("Свой пример", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Настройки")
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var startRequest: SessionRequest? {
        let ids = model.modeTopicIDs
        return ids.isEmpty ? nil : SessionRequest(topicIDs: ids)
    }

    /// Bit: пора повторить, слабое место или просто привет.
    @ViewBuilder
    private var bitCard: some View {
        if let review = model.dueReview {
            VStack(alignment: .leading, spacing: 12) {
                BitBubble(mood: .idle, title: "Пора повторить", subtitle: "Освоенное тоже забывается.", bitSize: 56)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.title).font(.subheadline.weight(.semibold))
                        Text("5 примеров").font(.footnote).foregroundStyle(Color.sub)
                    }
                    Spacer()
                    NavigationLink(value: Route.training(SessionRequest(topicIDs: [review.id], count: 5, isReview: true,
                                                                        title: "Повторение"))) {
                        Label("Повторить", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inverse)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.ink)
                }
                .contentCard(radius: 20, padding: 12)
            }
        } else if let weak = model.weakTopic {
            BitBubble(mood: .idle, title: "Слабое место: \(weak.title.lowercased()).", subtitle: "Начнём с него?", bitSize: 72)
        } else {
            BitBubble(mood: .idle, title: "Привет. Начнём?", subtitle: "Десять примеров — пара минут.", bitSize: 72)
        }
    }

    private var columnsPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Столбики", trailing: nil)
            GlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(2...9, id: \.self) { n in columnChip(n) }
                }
            }
            Button(model.columns.count == 8 ? "Сбросить" : "Все") {
                model.columns = model.columns.count == 8 ? [2, 3] : Set(2...9)
            }
            .font(.subheadline)
        }
        .sensoryFeedback(.selection, trigger: model.columns)
    }

    /// Выбранный столбик — залитое стекло, остальные — обычное.
    @ViewBuilder
    private func columnChip(_ n: Int) -> some View {
        let on = model.columns.contains(n)
        let label = Text("\(n)")
            .font(.numbers(24))
            .foregroundStyle(on ? Color.inverse : Color.ink)
            .frame(maxWidth: .infinity, minHeight: 40)
        let toggle = {
            if on { if model.columns.count > 1 { model.columns.remove(n) } } else { model.columns.insert(n) }
        }
        Group {
            if on {
                Button(action: toggle) { label }.buttonStyle(.glassProminent)
            } else {
                Button(action: toggle) { label }.buttonStyle(.glass)
            }
        }
        .tint(Color.ink)
        .buttonBorderShape(.roundedRectangle(radius: Metrics.controlRadius))
        .accessibilityLabel("Столбик \(n)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var topicsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Темы", trailing: summary)
            VStack(spacing: 0) {
                ForEach(Course.fractionTopics, id: \.self) { id in
                    if let t = Course.topic(id) {
                        topicRow(t)
                        if id != Course.fractionTopics.last { Divider().overlay(Color.hairline).padding(.leading, 44) }
                    }
                }
            }
            .contentCard(padding: 12)
        }
    }

    private func topicRow(_ t: TopicDef) -> some View {
        let on = model.fractionTopics.contains(t.id)
        let p = model.progress.progress(t.id)
        return HStack(spacing: 12) {
            Button {
                if on { model.fractionTopics.remove(t.id) } else { model.fractionTopics.insert(t.id) }
            } label: {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(on ? Color.ink : Color.faint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(on ? "Убрать из тренировки" : "Добавить в тренировку")
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if model.progress.isWeak(t.id, day: model.today) { Tag(text: "слабое", dashed: true) }
                    if model.progress.dueReviews(day: model.today).contains(t.id) { Tag(text: "повтор", dashed: false) }
                }
                Text(p.accuracyPercent.map { "точность \($0)%" } ?? "ещё не решал")
                    .font(.caption).foregroundStyle(Color.sub)
            }
            Spacer(minLength: 4)
            NavigationLink(value: Route.lesson(t.id)) {
                Text("Урок").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical, 8)
    }

    private var summary: String {
        let solved = model.progress.totalSolved
        let acc = model.progress.accuracyPercent.map { "\($0)%" } ?? "—"
        return "\(solved) решено · \(acc) · серия \(model.progress.streak)"
    }

    private var mixedNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Вперемешку")
            Text("Таблица умножения и все темы с дробями. Слабые темы выпадают чаще, освоенные — по графику повторения.")
                .font(.subheadline)
                .foregroundStyle(Color.sub)
                .contentCard(padding: 14)
        }
    }
}

/// Метка у темы: «слабое» — пунктир, «повтор» — сплошная рамка.
struct Tag: View {
    let text: String
    let dashed: Bool

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 1.2, dash: dashed ? [3, 3] : [])))
    }
}
