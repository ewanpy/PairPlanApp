import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var showAdd = false

    let sessionCode: String
    let mode: SessionMode

    init(sessionCode: String, mode: SessionMode) {
        self.sessionCode = sessionCode
        self.mode = mode
        _viewModel = StateObject(
            wrappedValue: TaskListViewModel(
                sessionCode: sessionCode,
                mode: mode
            )
        )
    }

    var body: some View {
        VStack {
            HStack {
                Text("Сессия: \(sessionCode)")
                Spacer()
                Button { showAdd.toggle() } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)

            if mode == .shared {
                List(viewModel.tasks) { task in
                    TaskRow(
                        task: task,
                        mode: mode,
                        currentUserId: viewModel.currentUserId
                    ) {
                        viewModel.toggleCompletion(of: task)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    // Мои задачи
                    VStack {
                        Text("Мои задачи").font(.headline)
                        List(viewModel.tasks.filter { $0.ownerId == viewModel.currentUserId }) { task in
                            TaskRow(
                                task: task,
                                mode: mode,
                                currentUserId: viewModel.currentUserId
                            ) {
                                viewModel.toggleCompletion(of: task)
                            }
                        }
                    }
                    Divider()
                    // Задачи партнёра
                    VStack {
                        Text("Задачи партнёра").font(.headline)
                        List(viewModel.tasks.filter { $0.ownerId != viewModel.currentUserId }) { task in
                            TaskRow(
                                task: task,
                                mode: mode,
                                currentUserId: viewModel.currentUserId
                            ) {
                                viewModel.toggleCompletion(of: task)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTaskView { title, date in
                viewModel.addTask(title: title, at: date)
                showAdd = false
            }
        }
    }
}

// Вспомогательный компонент для отображения строки задачи
struct TaskRow: View {
    let task: Task
    let mode: SessionMode
    let currentUserId: String
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .disabled(mode == .individual && task.ownerId != currentUserId)

            VStack(alignment: .leading) {
                Text(task.title)
                if let date = task.timestamp {
                    Text(date, style: .time)
                        .font(.caption)
                }
            }
        }
    }
}
