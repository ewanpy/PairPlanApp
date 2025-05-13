import Foundation
import FirebaseFirestore

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []

    private var listener: ListenerRegistration?
    private let sessionCode: String
    let mode: SessionMode
    let currentUserId: String

    // Ключ для хранения userId в UserDefaults
    private static let userIdKey = "PairPlan.currentUserId"

    init(sessionCode: String,
         mode: SessionMode)
    {
        self.sessionCode = sessionCode
        self.mode = mode

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
                self?.tasks = tasks
            }
        }
    }

    deinit {
        listener?.remove()
    }

    func addTask(title: String, at date: Date?) {
        let newTask = Task(
            id: UUID().uuidString,
            title: title,
            timestamp: date,
            isCompleted: false,
            ownerId: currentUserId
        )
        FirestoreManager.shared.upsertTask(sessionCode: sessionCode, task: newTask)
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
