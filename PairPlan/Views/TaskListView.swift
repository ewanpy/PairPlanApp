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
    @State private var selectedWeekday: Int = 1 // по умолчанию Пн
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "PairPlan.currentUserId") ?? ""
    }
    
    var body: some View {
        VStack {
            WeekdayPicker(selectedWeekday: $selectedWeekday)
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
                let filteredTasks = viewModel.tasks.filter {
                    $0.weekday == selectedWeekday
                }
                .filter { selectedTaskTypes.contains($0.type) }
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
                        previousUserId: prevUserId,
                        onEdit: {
                            editingTask = task
                            showEditSheet = true
                        },
                        onDelete: {
                            deleteTaskById(task.id)
                        },
                        onChecklist: {
                            checklistTask = task
                            showChecklistSheet = true
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
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
            AddTaskView(sessionCode: sessionCode, mode: mode, defaultWeekday: selectedWeekday)
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
                ChecklistMarkView(checklist: binding, isReadOnly: checklistTask.userId != currentUserId)
            }
        }
        .onAppear {
            selectedWeekday = getCurrentWeekday()
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

    func getCurrentWeekday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1 // 1=Пн, 7=Вс
    }
    func getCurrentWeekNumber() -> Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }
    func getCurrentYear() -> Int {
        Calendar.current.component(.year, from: Date())
    }
}

struct TaskRow: View {
    let task: Task
    let currentUserId: String
    let onToggleComplete: () -> Void
    let isIndividual: Bool
    let previousUserId: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onChecklist: () -> Void
    @State private var isPressed = false
    @State private var isLongPressed = false

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
                }
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: fontSize - 2))
                }
                if let checklist = task.checklist, !checklist.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(checklist.prefix(3)), id: \.id) { item in
                            HStack(spacing: 4) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                    .font(.system(size: fontSize - 4))
                                Text(item.text)
                                    .font(.system(size: fontSize - 4))
                                    .foregroundColor(item.isCompleted ? .gray : textColor)
                                    .strikethrough(item.isCompleted)
                                    .lineLimit(1)
                            }
                        }
                        if checklist.count > 3 {
                            Text("+\(checklist.count - 3)")
                                .font(.system(size: fontSize - 6))
                                .foregroundColor(.gray)
                        }
                    }
                }
                if let time = task.time {
                    HStack {
                        Image(systemName: "clock")
                        Text(time, style: .time)
                    }
                    .font(.system(size: fontSize - 2))
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .frame(maxWidth: 280, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bubbleColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isLongPressed ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundColor(textColor)
        }
        .onLongPressGesture(minimumDuration: 0.15, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isLongPressed = pressing
            }
        }, perform: {})
        .contextMenu {
            if task.userId == currentUserId {
                Button(action: onEdit) {
                    Label("Редактировать", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            }
            if let checklist = task.checklist, !checklist.isEmpty {
                Button(action: onChecklist) {
                    Label("Чеклист", systemImage: "checklist")
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selectedWeekday: Int
    let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button(action: { selectedWeekday = day }) {
                    Text(weekdays[day-1])
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(selectedWeekday == day ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selectedWeekday == day ? .white : .primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
}
