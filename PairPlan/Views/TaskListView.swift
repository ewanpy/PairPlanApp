import SwiftUI
import PhotosUI
import Foundation

// Основной экран отображения задач пользователя в рамках сессии.
// Позволяет фильтровать задачи по дню недели, типу, отмечать выполнение, редактировать, удалять и просматривать чеклисты.
struct TaskListView: View {
    /// Код сессии, к которой относятся задачи
    let sessionCode: String
    /// Режим сессии (shared/individual)
    let mode: SessionMode
    /// ViewModel для работы со списком задач
    @StateObject private var viewModel = TaskListViewModel()
    /// Флаг отображения экрана добавления задачи
    @State private var showingAddTask = false
    /// Выбранные типы задач для фильтрации
    @State private var selectedTaskTypes: Set<TaskType> = Set(TaskType.allCases)
    /// Флаг отображения экрана редактирования задачи
    @State private var showEditSheet = false
    /// Задача, выбранная для редактирования
    @State private var editingTask: Task? = nil
    /// Флаг отображения экрана чеклиста
    @State private var showChecklistSheet = false
    /// Задача, чеклист которой просматривается
    @State private var checklistTask: Task? = nil
    /// Выбранный день недели (1 = Пн, 7 = Вс)
    @State private var selectedWeekday: Int = 1 // по умолчанию Пн
    /// Текущий пользователь (id)
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "PairPlan.currentUserId") ?? ""
    }
    
    var body: some View {
        VStack {
            // Меню выбора дня недели с визуализацией статуса дней
            WeekdayPicker(selectedWeekday: $selectedWeekday)
            // Фильтр по типу задач (только для общего режима)
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
            // Список задач, отфильтрованный по дню недели и типу, отсортированный по времени
            List {
                // Фильтрация и сортировка задач
                let filteredTasks = viewModel.tasks
                    .filter { $0.weekday == selectedWeekday }
                    .filter { selectedTaskTypes.contains($0.type) }
                    .sorted {
                        // Сортировка: сначала задачи без времени, затем по времени (24ч)
                        switch ($0.time, $1.time) {
                        case let (t0?, t1?):
                            return t0 < t1
                        case (nil, nil):
                            return false
                        case (nil, _?):
                            return true
                        case (_?, nil):
                            return false
                        }
                    }
                // Отображение каждой задачи через TaskRow
                ForEach(Array(filteredTasks.enumerated()), id: \ .element.id) { index, task in
                    let prevUserId = index > 0 ? filteredTasks[index-1].userId : nil
                    TaskRow(
                        task: task,
                        currentUserId: currentUserId,
                        onToggleComplete: {
                            // Переключение выполнения задачи с анимацией
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
            // Кнопка добавления задачи
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        // Экран добавления задачи
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(sessionCode: sessionCode, mode: mode, defaultWeekday: selectedWeekday)
        }
        // Экран редактирования задачи
        .sheet(isPresented: $showEditSheet) {
            if let editingTask = editingTask {
                EditTaskView(task: editingTask) { updatedTask in
                    // Сохраняем изменения через FirestoreManager
                    FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                    showEditSheet = false
                }
            }
        }
        // Экран просмотра чеклиста
        .sheet(isPresented: $showChecklistSheet) {
            if let checklistTask = checklistTask, let binding = bindingForTask(withId: checklistTask.id) {
                ChecklistMarkView(checklist: binding, isReadOnly: checklistTask.userId != currentUserId)
            }
        }
        // Загрузка задач при появлении экрана
        .onAppear {
            selectedWeekday = getCurrentWeekday()
            viewModel.loadTasks(for: sessionCode)
        }
    }

    // Переключает состояние чеклиста у задачи (отметка/снятие выполнения пункта)
    private func toggleChecklistItem(task: Task, item: ChecklistItem) {
        guard var checklist = task.checklist,
              let idx = checklist.firstIndex(where: { $0.id == item.id }) else { return }
        checklist[idx].isCompleted.toggle()
        var updatedTask = task
        updatedTask.checklist = checklist
        // Обновить задачу в Firestore
        FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
    }

    // Удаляет задачу по id из списка задач и из Firestore
    private func deleteTaskById(_ id: String) {
        if let idx = viewModel.tasks.firstIndex(where: { $0.id == id }) {
            let indexSet = IndexSet(integer: idx)
            viewModel.deleteTasks(at: indexSet)
        }
    }

    // Находит биндинг для чеклиста задачи по id (для передачи в ChecklistMarkView)
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

    // Возвращает текущий день недели (1 = Пн, 7 = Вс) по локали пользователя
    func getCurrentWeekday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1 // 1=Пн, 7=Вс
    }

    // Возвращает номер текущей недели в году
    func getCurrentWeekNumber() -> Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }

    // Возвращает текущий год
    func getCurrentYear() -> Int {
        Calendar.current.component(.year, from: Date())
    }
}

// Строка задачи в списке. Отвечает за отображение, анимацию, контекстное меню и визуализацию статуса задачи.
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

// Компонент для выбора дня недели. Визуально выделяет прошедшие, текущий и будущие дни.
// Используется для фильтрации задач по дню недели.
struct WeekdayPicker: View {
    @Binding var selectedWeekday: Int
    let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    var body: some View {
        let today = getCurrentWeekday()
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isPast = day < today
                let isToday = day == today
                let isFuture = day > today
                Button(action: { selectedWeekday = day }) {
                    Text(weekdays[day-1])
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(
                            isToday ? Color.accentColor :
                            selectedWeekday == day ? Color.accentColor.opacity(0.5) :
                            isPast ? Color(.systemGray5) : Color(.systemGray6)
                        )
                        .foregroundColor(
                            isToday ? .white :
                            isPast ? .gray :
                            .primary
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isToday ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(8)
                        .opacity(isPast ? 0.5 : 1.0)
                }
            }
        }
        .padding(.horizontal)
    }
    // Возвращает текущий день недели (1 = Пн, 7 = Вс)
    func getCurrentWeekday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }
}
