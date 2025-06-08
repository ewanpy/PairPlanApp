import SwiftUI
import Firebase
import UserNotifications

@main
struct PairPlanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isAuthenticated: Bool = false
    
    init() {
        // Запрашиваем разрешение на уведомления при запуске приложения
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Разрешение на уведомления получено")
            } else if let error = error {
                print("Ошибка при запросе разрешения на уведомления: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    SessionView(onLogout: {
                        do {
                            try AuthManager.shared.logout()
                        } catch {
                            print("Ошибка выхода из аккаунта:", error)
                        }
                        isAuthenticated = false
                    })
                    .environmentObject(SessionViewModel())
                } else {
                    AuthView(isAuthenticated: $isAuthenticated)
                }
            }
            .onAppear {
                isAuthenticated = AuthManager.shared.currentUser != nil
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        return true
    }
    
    // Регистрируем категории и действия для уведомлений
    private func registerNotificationCategories() {
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Отложить", options: [])
        let cancelAction = UNNotificationAction(identifier: "CANCEL_ACTION", title: "Отменить", options: [.destructive])
        let doneAction = UNNotificationAction(identifier: "DONE_ACTION", title: "Выполнено", options: [.authenticationRequired])
        let category = UNNotificationCategory(identifier: "TASK_CATEGORY", actions: [snoozeAction, cancelAction, doneAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Обработка уведомлений, когда приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Обработка нажатия на уведомление
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let components = identifier.split(separator: "_")
        guard components.count >= 2 else {
            completionHandler()
            return
        }
        let sessionCode = String(components[0])
        let taskId = components.dropFirst().joined(separator: "_")
        
        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            FirestoreManager.shared.updateTaskStatus(sessionCode: sessionCode, taskId: taskId, status: .snoozed)
        case "CANCEL_ACTION":
            FirestoreManager.shared.updateTaskStatus(sessionCode: sessionCode, taskId: taskId, status: .cancelled)
        case "DONE_ACTION":
            FirestoreManager.shared.updateTaskStatus(sessionCode: sessionCode, taskId: taskId, status: .done)
        default:
            break
        }
        completionHandler()
    }
}
