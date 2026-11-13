import SwiftUI
import MathCore

/// Маршруты внутри вкладок.
enum Route: Hashable {
    case training(SessionRequest)
    case lesson(String)
    case topic(String)
    case topicStats(String)
    case solve(Problem)
    case custom
}

/// Три вкладки. Системный TabView в iOS 26 сам получает Liquid Glass.
struct RootView: View {
    @State private var tab: Int

    init(tab: Int = 0) {
        _tab = State(initialValue: tab)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Тренировка", systemImage: "square.grid.2x2", value: 0) {
                NavigationStack { HomeView().withRoutes() }
            }
            Tab("Курс", systemImage: "book", value: 1) {
                NavigationStack { CourseView().withRoutes() }
            }
            Tab("Статистика", systemImage: "chart.bar", value: 2) {
                NavigationStack { StatsView().withRoutes() }
            }
        }
    }
}

extension View {
    /// Общие переходы для всех вкладок.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .training(let request): TrainingView(request: request)
            case .lesson(let id): LessonView(topicID: id)
            case .topic(let id): TopicCardView(topicID: id)
            case .topicStats(let id): TopicStatsView(topicID: id)
            case .solve(let problem): SolveView(problem: problem)
            case .custom: CustomExampleView()
            }
        }
    }
}

/// Обёртка для sheet(item:).
struct SheetProblem: Identifiable {
    let id = UUID()
    let problem: Problem
    var level = 1
}
