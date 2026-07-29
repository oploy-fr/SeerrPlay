import SwiftUI

@main
struct SeerrPlayApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .task {
                    await app.bootstrap()
                }
        }
    }
}
