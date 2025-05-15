import Foundation
import FirebaseFirestore
import UserNotifications

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []

    private var listener: ListenerRegistration?
    private let sessionCode: String
    let mode: SessionMode
    let currentUserId: String
    private static let userIdKey = "PairPlan.currentUserId"
    private var lastTaskIds: Set<String> = []

    init(sessionCode: String,
         mode: SessionMode)
    {
        self.sessionCode = sessionCode
        self.mode = mode

        // Request notification permission at first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // You can handle permission granted/denied here if needed
        }

        // Если в UserDefaults уже есть наш userId — читаем его,
        // иначе создаём новый и сохраняем.
        if let saved = UserDefaults.standard.string(forKey: Self.userIdKey) {
            self.currentUserId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: Self.userIdKey)
            self.currentUserId = newId
        }

        // Подписка на задачи
        listener = FirestoreManager.shared.observeTasks(sessionCode: sessionCode) { [weak self] tasks in
            DispatchQueue.main.async {
                if let self = self {
                    let newTasks = tasks.filter { !self.lastTaskIds.contains($0.id) }
                    for task in newTasks {
                        if (self.mode == .shared || task.ownerId == self.currentUserId),
                           task.ownerId == self.currentUserId {
                            self.scheduleTaskNotification(task: task)
                        }
                    }
                    self.lastTaskIds = Set(tasks.map { $0.id })
                }
                self?.tasks = tasks
            }
        }
    }

    private func scheduleTaskNotification(task: Task) {
        let content = UNMutableNotificationContent()
        content.title = "Новая задача"
        content.body = task.title
        content.sound = .default

        // Show immediately, or you can schedule for task.timestamp if you want
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: task.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    deinit {
        listener?.remove()
    }

    func addTask(title: String, at date: Date?, type: TaskType, colorHex: String? = nil, description: String? = nil, attachments: [String]? = nil, repeatRule: String? = nil, checklist: [ChecklistItem]? = nil) {
        let newTask = Task(
            id: UUID().uuidString,
            title: title,
            timestamp: date,
            isCompleted: false,
            ownerId: currentUserId,
            type: type,
            color: colorHex,
            description: description,
            attachments: attachments,
            repeatRule: repeatRule,
            checklist: checklist
        )
        FirestoreManager.shared.upsertTask(sessionCode: sessionCode, task: newTask)
    }

    func updateTask(_ task: Task) {
        FirestoreManager.shared.upsertTask(sessionCode: sessionCode, task: task)
    }

    func deleteTask(_ task: Task) {
        FirestoreManager.shared.deleteTask(sessionCode: sessionCode, taskId: task.id)
    }

    func toggleCompletion(of task: Task) {
        guard mode == .shared || task.ownerId == currentUserId else {
            return
        }
        var updated = task
        updated.isCompleted.toggle()
        FirestoreManager.shared.upsertTask(sessionCode: sessionCode, task: updated)
    }
}
