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
    /// Задача, выбранная для редактирования
    @State private var editingTask: Task? = nil
    /// Флаг отображения экрана чеклиста (только просмотр)
    @State private var showChecklistSheet = false
    /// Задача, чеклист которой просматривается (только просмотр)
    @State private var checklistTask: Task? = nil
    /// Задача для редактирования чеклиста
    @State private var editingChecklistTask: Task? = nil
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
            
            // Список задач, отфильтрованный по дню недели, отсортированный по времени
            List {
                // Фильтрация и сортировка задач
                let filteredTasks = viewModel.tasks
                    .filter { $0.weekday == selectedWeekday }
                    .sorted {
                        // Сортировка по времени в формате 24 часа
                        switch ($0.time, $1.time) {
                        case let (t0?, t1?):
                            // Если у обеих задач есть время, сравниваем их
                            return t0 < t1
                        case (nil, nil):
                            // Если у обеих задач нет времени, сортируем по времени создания
                            return $0.timestamp > $1.timestamp
                        case (nil, _?):
                            // Задачи без времени идут в конец
                            return false
                        case (_?, nil):
                            // Задачи с временем идут в начало
                            return true
                        }
                    }
                // Отображение каждой задачи через TaskRow
                ForEach(filteredTasks) { task in
                    TaskRow(
                        task: task,
                        currentUserId: currentUserId,
                        sessionCode: sessionCode,
                        onToggleComplete: {
                            viewModel.toggleTaskCompletion(sessionCode: sessionCode, task: task)
                        },
                        isIndividual: mode == .individual,
                        previousUserId: nil, // Можно реализовать если нужно
                        onEdit: { editingTask = task },
                        onDelete: { deleteTaskById(task.id) },
                        onChecklist: { checklistTask = task },
                        onEditChecklist: {
                            editingChecklistTask = task
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { offsets in
                    viewModel.deleteTasks(at: offsets)
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color(.systemGray6).ignoresSafeArea())
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
            let dayTasks = viewModel.tasks.filter { $0.weekday == selectedWeekday }
            AddTaskView(
                sessionCode: sessionCode,
                mode: mode,
                defaultWeekday: selectedWeekday,
                existingTasks: dayTasks
            )
        }
        // Экран редактирования задачи
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task) { updatedTask in
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                editingTask = nil // Закрыть sheet после сохранения
            }
        }
        // Экран просмотра чеклиста
        .sheet(item: $checklistTask) { task in
            if let binding = bindingForTask(withId: task.id) {
                ChecklistMarkView(checklist: binding, isReadOnly: task.userId != currentUserId)
            }
        }
        .sheet(item: $editingChecklistTask) { task in
            if let binding = bindingForTask(withId: task.id) {
                ChecklistEditorView(checklist: binding)
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
                updatedTask.checklist = newValue.isEmpty ? nil : newValue
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                // Обновляем локально, чтобы sheet сразу отобразил изменения
                viewModel.tasks[idx].checklist = newValue.isEmpty ? nil : newValue
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

// Строка задачи в списке. Отвечает за отображение задачи, анимацию, контекстное меню и визуализацию статуса задачи.
struct TaskRow: View {
    /// Задача, которую отображает строка
    let task: Task
    /// ID текущего пользователя (для определения владельца задачи)
    let currentUserId: String
    /// Код сессии
    let sessionCode: String
    /// Callback для переключения выполнения задачи
    let onToggleComplete: () -> Void
    /// Флаг индивидуального режима (меняет стиль отображения)
    let isIndividual: Bool
    /// ID пользователя предыдущей задачи (для визуального разделения)
    let previousUserId: String?
    /// Callback для редактирования задачи
    let onEdit: () -> Void
    /// Callback для удаления задачи
    let onDelete: () -> Void
    /// Callback для открытия чеклиста задачи
    let onChecklist: () -> Void
    /// Callback для редактирования чеклиста задачи
    let onEditChecklist: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if task.status == .cancelled {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            } else {
                Image(systemName: task.isCompleted || task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .green : task.status == .snoozed ? .orange : task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            Image(systemName: task.type.icon)
                .foregroundColor(.accentColor)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(task.status == .cancelled ? .red : .primary)
                    .strikethrough(task.isCompleted || task.status == .done || task.status == .cancelled)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(task.status == .cancelled ? .red : .secondary)
                        .strikethrough(task.isCompleted || task.status == .done || task.status == .cancelled)
                }
                if let time = task.time {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(time, style: .time)
                            .font(.caption)
                        if let endTime = task.endTime {
                            Text("-")
                                .font(.caption)
                            Text(endTime, style: .time)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    task.status == .done ? Color.green.opacity(0.18) :
                    task.status == .snoozed ? Color.orange.opacity(0.18) :
                    task.status == .cancelled ? Color.red.opacity(0.18) :
                    task.isCompleted ? Color.green.opacity(0.18) : Color(.systemGray5)
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onTapGesture {
            if task.status != .cancelled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = true
                    onToggleComplete()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isPressed = false
                    }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: {
                // Отменить задачу (красный)
                var updatedTask = task
                updatedTask.status = .cancelled
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
            }) {
                Label("Отменить", systemImage: "xmark.circle")
            }.tint(.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: {
                // Отложить задачу (оранжевый)
                var updatedTask = task
                updatedTask.status = .snoozed
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
            }) {
                Label("Отложить", systemImage: "clock.arrow.circlepath")
            }.tint(.orange)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Редактировать", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
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
    /// Привязка к выбранному дню недели (1 = Пн, 7 = Вс)
    @Binding var selectedWeekday: Int
    /// Массив коротких названий дней недели
    let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    var body: some View {
        let today = getCurrentWeekday()
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isPast = day < today
                let isToday = day == today
                // Кнопка выбора дня недели
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
    /// Возвращает текущий день недели (1 = Пн, 7 = Вс) по локали пользователя
    func getCurrentWeekday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }
}
