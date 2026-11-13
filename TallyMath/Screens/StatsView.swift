import SwiftUI
import MathCore

/// Вкладка «Статистика»: итоги за период, тепловая карта таблицы умножения, точность по темам.
struct StatsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case week = "Неделя", month = "Месяц", all = "Всё время"
        var id: String { rawValue }
        var days: Int? { self == .week ? 7 : (self == .month ? 30 : nil) }
    }

    @Environment(AppModel.self) private var model
    @State private var period: Period = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack(spacing: 10) {
                    StatTile(value: "\(solved)", caption: "решено")
                    StatTile(value: accuracy.map { "\($0)%" } ?? "—", caption: "точность")
                    StatTile(value: "\(model.progress.bestStreak)", caption: "лучшая серия")
                }
                heatmap
                topicsCard
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .navigationTitle("Статистика")
    }

    private var sessions: [SessionRecord] {
        let today = model.today
        return model.progress.sessions.filter { s in period.days.map { today - s.day < $0 } ?? true }
    }

    private var solved: Int {
        let today = model.today
        return model.progress.solvedByDay.filter { d, _ in period.days.map { today - d < $0 } ?? true }.values.reduce(0, +)
    }

    private var accuracy: Int? {
        let results = sessions.flatMap { $0.results }
        return results.isEmpty ? model.progress.accuracyPercent : results.filter { $0 }.count * 100 / results.count
    }

    /// Один оттенок: чем больше ошибок, тем темнее (в тёмной теме — светлее).
    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Таблица умножения").font(.headline)
            Text("Чем ярче клетка, тем больше ошибок").font(.caption).foregroundStyle(Color.sub)
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    Text("")
                    ForEach(2...9, id: \.self) { b in Text("\(b)").font(.caption2.weight(.semibold)).foregroundStyle(Color.sub) }
                }
                ForEach(2...9, id: \.self) { a in
                    GridRow {
                        Text("\(a)").font(.caption2.weight(.semibold)).foregroundStyle(Color.sub)
                        ForEach(2...9, id: \.self) { b in cell(a, b) }
                    }
                }
            }
            if let worst = worstFacts, !worst.isEmpty {
                Text("Слабее всего: " + worst.joined(separator: ", ")).font(.subheadline.weight(.semibold))
            }
        }
        .contentCard()
    }

    private func cell(_ a: Int, _ b: Int) -> some View {
        let rate = model.progress.factErrorRate(a, b)
        let value = rate.map { Double($0.num) / Double($0.den) } ?? 0
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.ink.opacity(rate == nil ? 0.05 : 0.08 + value * 0.9))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if value >= 0.5 {
                    Text("\(a * b)").font(.numbers(10, .bold)).foregroundStyle(Color.inverse)
                }
            }
            .accessibilityLabel("\(a) на \(b): " + (rate == nil ? "не решал" : "ошибок \(Int(value * 100))%"))
    }

    private var worstFacts: [String]? {
        let list = model.progress.facts.compactMap { key, answers -> (String, Double)? in
            let wrong = answers.filter { !$0 }.count
            return wrong == 0 ? nil : (key.replacingOccurrences(of: "×", with: " × "), Double(wrong) / Double(answers.count))
        }
        return list.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }

    private var topicsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("По темам").font(.headline)
            let ids = model.progress.topics.keys.sorted { a, b in
                (model.progress.progress(a).accuracyPercent ?? 100) < (model.progress.progress(b).accuracyPercent ?? 100)
            }
            if ids.isEmpty {
                Text("Пока пусто. Реши несколько примеров.").foregroundStyle(Color.sub)
            }
            ForEach(ids, id: \.self) { id in
                if let t = Course.topic(id) {
                    NavigationLink(value: Route.topicStats(id)) {
                        topicRow(t)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentCard()
    }

    private func topicRow(_ t: TopicDef) -> some View {
        let p = model.progress.progress(t.id)
        let acc = Double(p.accuracyPercent ?? 0) / 100
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                if model.progress.isWeak(t.id, day: model.today) { Tag(text: "слабое", dashed: true) }
                Spacer()
                Text(p.accuracyPercent.map { "\($0)%" } ?? "—").font(.numbers(15, .bold))
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.faint)
            }
            AccuracyBar(fraction: acc)
            if !p.notUnderstoodDays.isEmpty {
                Text("«не понял» ×\(p.notUnderstoodDays.count)").font(.caption).foregroundStyle(Color.sub)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Экран темы: точность, тренд по сессиям, частые ошибки, «Тренировать» и «Повторить урок».
struct TopicStatsView: View {
    let topicID: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.progress.progress(topicID)
        let mistakes = model.progress.topMistakes(topicID)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(p.accuracyPercent.map { "\($0)%" } ?? "—").font(.numbers(56, .bold))
                    VStack(alignment: .leading) {
                        Text("точность").foregroundStyle(Color.sub)
                        Text("\(p.attempts) примеров").foregroundStyle(Color.sub)
                    }
                }
                trend
                if let top = mistakes.first {
                    BitBubble(mood: .hint, title: "Чаще всего: \(top.0.title.lowercased())", subtitle: top.0.hint, bitSize: 56)
                }
                if !mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Частые ошибки").font(.headline)
                        ForEach(mistakes.indices, id: \.self) { i in
                            HStack {
                                Text(mistakes[i].0.title).font(.subheadline)
                                Spacer()
                                Text("×\(mistakes[i].1)").font(.numbers(14, .bold))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.3))
                            }
                        }
                    }
                    .contentCard()
                }
                if !p.notUnderstoodDays.isEmpty {
                    Text("«Не понял» ×\(p.notUnderstoodDays.count) — тема выпадает чаще")
                        .font(.footnote).foregroundStyle(Color.sub)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.3, dash: [4, 4])))
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    NavigationLink(value: Route.training(SessionRequest(topicIDs: [topicID]))) {
                        Text("Тренировать").font(.headline).frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.glass)
                    NavigationLink(value: Route.lesson(topicID)) {
                        Text("Повторить урок").font(.headline).foregroundStyle(Color.inverse).frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.ink)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .navigationTitle(Course.topic(topicID)?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Точность в последних 10 сессиях по теме: линия 2pt, последняя точка выделена.
    private var trend: some View {
        let all: [Double] = model.progress.sessions.compactMap { s in
            let mine = zip(s.topicIDs, s.results).filter { $0.0 == topicID }.map { $0.1 }
            return mine.isEmpty ? nil : Double(mine.filter { $0 }.count) / Double(mine.count)
        }
        let values = Array(all.suffix(10))
        return VStack(alignment: .leading, spacing: 8) {
            Text("Последние сессии").font(.headline)
            if values.count < 2 {
                Text("Нужно хотя бы две сессии по теме.").font(.subheadline).foregroundStyle(Color.sub)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let pts = values.enumerated().map { i, v in
                        CGPoint(x: w * CGFloat(i) / CGFloat(values.count - 1), y: h * (1 - CGFloat(v)))
                    }
                    ZStack {
                        ForEach([0.0, 0.5, 1.0], id: \.self) { g in
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: h * (1 - g)))
                                p.addLine(to: CGPoint(x: w, y: h * (1 - g)))
                            }
                            .stroke(Color.hairline)
                        }
                        Path { p in p.addLines(pts) }
                            .stroke(Color.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        if let last = pts.last {
                            Circle().fill(Color.ink).frame(width: 10, height: 10).position(last)
                            Text("\(Int((values.last ?? 0) * 100))%").font(.numbers(12, .bold))
                                .position(x: last.x - 22, y: max(10, last.y - 14))
                        }
                    }
                }
                .frame(height: 110)
                .accessibilityElement()
                .accessibilityLabel("Точность по сессиям: " + values.map { "\(Int($0 * 100))%" }.joined(separator: ", "))
            }
        }
        .contentCard()
    }
}
