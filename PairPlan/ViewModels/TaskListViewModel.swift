import Foundation
import FirebaseFirestore
import Combine

// ViewModel для работы со списком задач. Загружает, удаляет и обновляет задачи из Firestore.
class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    var sessionCode: String = ""

    /// Загружает задачи для указанного кода сессии
    func loadTasks(for sessionCode: String) {
        self.sessionCode = sessionCode
        FirestoreManager.shared.loadTasks(sessionCode: sessionCode) { [weak self] tasks in
            DispatchQueue.main.async {
                self?.tasks = tasks
            }
        }
    }

    /// Удаляет задачи по индексам
    func deleteTasks(at offsets: IndexSet) {
        let tasksToDelete = offsets.map { tasks[$0] }
        for task in tasksToDelete {
            FirestoreManager.shared.deleteTask(sessionCode: sessionCode, task: task) { error in
                // Локальный массив обновится через snapshotListener
            }
        }
    }

    /// Переключает состояние выполнения задачи
    func toggleTaskCompletion(sessionCode: String, task: Task) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.isCompleted.toggle()
            let oldTask = tasks[idx]
            tasks[idx] = updatedTask
            FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { [weak self] error in
                if let error = error {
                    print("Error updating task: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.tasks[idx] = oldTask
                    }
                }
            }
        }
    }
}
