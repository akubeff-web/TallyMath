import SwiftUI

/// Настройки: сброс прогресса и пара слов о приложении. Всё хранится только на телефоне.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Сбросить прогресс", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Статистика, слабые места и график повторений хранятся только на этом iPhone.")
                }
                Section("О приложении") {
                    LabeledContent("Версия", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Text("Тренажёр математики 5–8 классов. Без сети, аккаунтов и аналитики.")
                        .font(.footnote).foregroundStyle(Color.sub)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
            .confirmationDialog("Сбросить весь прогресс?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Сбросить", role: .destructive) { model.resetProgress() }
            }
        }
    }
}
