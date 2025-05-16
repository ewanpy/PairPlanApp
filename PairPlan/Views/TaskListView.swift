import SwiftUI
import PhotosUI
import Foundation

struct TaskListView: View {
    let sessionCode: String
    let mode: SessionMode
    @StateObject private var viewModel = TaskListViewModel()
    @State private var showingAddTask = false
    @State private var selectedTaskTypes: Set<TaskType> = Set(TaskType.allCases)
    @State private var showEditSheet = false
    @State private var editingTask: Task? = nil
    @State private var showChecklistSheet = false
    @State private var checklistTask: Task? = nil
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "PairPlan.currentUserId") ?? ""
    }
    
    var body: some View {
        VStack {
            // Task type filter (only for shared mode)
            if mode == .shared {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Button(action: {
                                if selectedTaskTypes.contains(type) {
                                    selectedTaskTypes.remove(type)
                                } else {
                                    selectedTaskTypes.insert(type)
                                }
                            }) {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.description)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedTaskTypes.contains(type) ? Color.accentColor : Color(.systemGray5))
                                )
                                .foregroundColor(selectedTaskTypes.contains(type) ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            // Task list
            List {
                let filteredTasks = viewModel.tasks.filter { selectedTaskTypes.contains($0.type) }
                    .sorted {
                        if $0.time == nil && $1.time != nil {
                            return true
                        } else if $0.time != nil && $1.time == nil {
                            return false
                        } else if let t0 = $0.time, let t1 = $1.time {
                            return t0 < t1
                        } else {
                            return false
                        }
                    }
                ForEach(Array(filteredTasks.enumerated()), id: \ .element.id) { index, task in
                    let prevUserId = index > 0 ? filteredTasks[index-1].userId : nil
                    TaskRow(
                        task: task,
                        currentUserId: currentUserId,
                        onToggleComplete: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.toggleTaskCompletion(sessionCode: sessionCode, task: task)
                            }
                        },
                        isIndividual: mode == .individual,
                        previousUserId: prevUserId
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .contextMenu {
                        if task.userId == currentUserId {
                            Button(action: {
                                editingTask = task
                                showEditSheet = true
                            }) {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                deleteTaskById(task.id)
                            }) {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        if let checklist = task.checklist, !checklist.isEmpty {
                            Button(action: {
                                checklistTask = task
                                showChecklistSheet = true
                            }) {
                                Label("Чеклист", systemImage: "checklist")
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Сессия \(sessionCode)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(sessionCode: sessionCode, mode: mode)
        }
        .sheet(isPresented: $showEditSheet) {
            if let editingTask = editingTask {
                EditTaskView(task: editingTask) { updatedTask in
                    // Сохраняем изменения через FirestoreManager
                    FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                    showEditSheet = false
                }
            }
        }
        .sheet(isPresented: $showChecklistSheet) {
            if let checklistTask = checklistTask, let binding = bindingForTask(withId: checklistTask.id) {
                ChecklistMarkView(checklist: binding)
            }
        }
        .onAppear {
            viewModel.loadTasks(for: sessionCode)
        }
    }

    private func toggleChecklistItem(task: Task, item: ChecklistItem) {
        guard var checklist = task.checklist,
              let idx = checklist.firstIndex(where: { $0.id == item.id }) else { return }
        checklist[idx].isCompleted.toggle()
        var updatedTask = task
        updatedTask.checklist = checklist
        // Обновить задачу в Firestore
        FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
    }

    private func deleteTaskById(_ id: String) {
        if let idx = viewModel.tasks.firstIndex(where: { $0.id == id }) {
            let indexSet = IndexSet(integer: idx)
            viewModel.deleteTasks(at: indexSet)
        }
    }

    private func bindingForTask(withId id: String) -> Binding<[ChecklistItem]>? {
        guard let idx = viewModel.tasks.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { viewModel.tasks[idx].checklist ?? [] },
            set: { newValue in
                var updatedTask = viewModel.tasks[idx]
                updatedTask.checklist = newValue
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
            }
        )
    }
}

struct TaskRow: View {
    let task: Task
    let currentUserId: String
    let onToggleComplete: () -> Void
    let isIndividual: Bool
    let previousUserId: String?
    @State private var isPressed = false

    var isCurrentUser: Bool { task.userId == currentUserId }
    var bubbleColor: Color {
        if task.isCompleted {
            if isCurrentUser {
                return Color.green.opacity(0.13)
            } else {
                return Color.teal.opacity(0.18)
            }
        } else if isCurrentUser {
            return Color(.systemGray6)
        } else {
            return Color.accentColor.opacity(0.85)
        }
    }
    var textColor: Color {
        if task.isCompleted && !isCurrentUser {
            return .primary
        } else {
            return isCurrentUser ? .primary : .white
        }
    }
    var alignment: Alignment { isCurrentUser ? .leading : .trailing }

    var bubbleHeight: CGFloat { isIndividual ? 42 : 50 }
    var fontSize: CGFloat { isIndividual ? 17 : 20 }
    var circleSize: CGFloat { isIndividual ? 20 : 24 }
    var horizontalPadding: CGFloat { isIndividual ? 14 : 20 }
    var verticalSpacing: CGFloat {
        if isIndividual, let prev = previousUserId, prev == task.userId {
            return 6
        } else if isIndividual {
            return 10
        } else {
            return 14
        }
    }

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            Group {
                if isCurrentUser {
                    Button(action: {
                        isPressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            isPressed = false
                            onToggleComplete()
                        }
                    }) {
                        bubbleContent
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(isPressed ? 0.97 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                } else {
                    bubbleContent
                }
            }
            if !isCurrentUser { Spacer() }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .padding(.vertical, verticalSpacing)
    }

    private var bubbleContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: fontSize + 2))
                    }
                    Text(task.title)
                        .font(.system(size: fontSize + 2, weight: .bold))
                        .foregroundColor(textColor)
                        .strikethrough(task.isCompleted)
                        .opacity(task.isCompleted ? 0.45 : 1.0)
                        .padding(.trailing, 54)
                }
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: fontSize - 2))
                        .foregroundColor(textColor.opacity(0.7))
                        .lineLimit(2)
                        .padding(.top, 2)
                        .opacity(task.isCompleted ? 0.35 : 1.0)
                        .padding(.trailing, 54)
                }
                if let checklist = task.checklist, !checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(checklist.prefix(5))) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                    .font(.system(size: fontSize - 4))
                                Text(item.text)
                                    .font(.system(size: fontSize - 4))
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(item.isCompleted ? .gray : textColor)
                                    .opacity(item.isCompleted ? 0.5 : 1.0)
                            }
                        }
                        if checklist.count > 5 {
                            Text("ещё \(checklist.count - 5)...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.trailing, 54)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 54)
            if let time = task.time {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding([.bottom, .trailing], 8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(bubbleColor)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .overlay(
            Group {
                if task.isCompleted && !isCurrentUser {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.green, lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.gray.opacity(0.13), lineWidth: 1)
                }
            }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPressed)
    }
}
