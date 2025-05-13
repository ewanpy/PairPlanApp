import SwiftUI
import Firebase

@main
struct PairPlanApp: App {
    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SessionView()
                .environmentObject(SessionViewModel())
        }
    }
}
