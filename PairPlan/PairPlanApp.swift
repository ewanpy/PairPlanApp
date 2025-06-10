import SwiftUI
import Firebase
import UserNotifications

@main
struct PairPlanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Новый enum для этапов аутентификации
    enum AuthStage {
        case auth
        case username(userId: String, email: String)
        case main
    }
    @State private var authStage: AuthStage = .auth
    @State private var appColorScheme: ColorScheme? = nil // Новый state для темы
    
    init() {
        // Запрашиваем разрешение на уведомления при запуске приложения
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Разрешение на уведомления получено")
            } else if let error = error {
                print("Ошибка при запросе разрешения на уведомления: \(error)")
            }
        }
        // Чтение темы из UserDefaults
        if let saved = UserDefaults.standard.string(forKey: "PairPlan.AppColorScheme") {
            switch saved {
            case "light": self._appColorScheme = State(initialValue: .light)
            case "dark": self._appColorScheme = State(initialValue: .dark)
            default: self._appColorScheme = State(initialValue: nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authStage {
                case .auth:
                    AuthView(isAuthenticated: .constant(false), onRegisterSuccess: { userId, email in
                        authStage = .username(userId: userId, email: email)
                    })
                case .username(let userId, let email):
                    UsernameView(userId: userId, email: email) {
                        authStage = .main
                    }
                case .main:
                    SessionView(onLogout: {
                        do {
                            try AuthManager.shared.logout()
                        } catch {
                            print("Ошибка выхода из аккаунта:", error)
                        }
                        authStage = .auth
                    }, appColorScheme: $appColorScheme)
                    .environmentObject(SessionViewModel())
                }
            }
            .preferredColorScheme(appColorScheme)
            .onAppear {
                if let user = AuthManager.shared.currentUser {
                    // Проверяем, есть ли username в Firestore
                    FirestoreManager.shared.getUsername(userId: user.uid) { username in
                        DispatchQueue.main.async {
                            if let _ = username {
                                authStage = .main
                            } else {
                                authStage = .username(userId: user.uid, email: user.email ?? "")
                            }
                        }
                    }
                } else {
                    authStage = .auth
                }
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
