import SwiftUI

@main
struct TallyMathApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if LaunchOptions.current.screen != nil {
                    PreviewRouter(options: LaunchOptions.current)
                } else {
                    RootView()
                }
            }
            .environment(model)
            // Никаких цветных акцентов: системные элементы берут чёрный / белый.
            .tint(Color.ink)
        }
    }
}
