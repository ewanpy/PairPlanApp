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
    /// Флаг отображения экрана добавления задачи
    @Binding var showAddTask: Bool
    /// ViewModel для работы со списком задач
    @StateObject private var viewModel = TaskListViewModel()
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
    /// Флаг отображения предупреждения удаления всех задач за выбранный день
    @State private var showDeleteDayAlert = false
    /// Текущий пользователь (id)
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "PairPlan.currentUserId") ?? ""
    }
    /// Доступ к SessionViewModel для username-кэша
    @EnvironmentObject var sessionVM: SessionViewModel
    
    // Добавляю computed property для элементов таймлайна
    private var timelineItems: [AnyView] {
        let filteredTasks = viewModel.tasks
            .filter { $0.weekday == selectedWeekday }
            .sorted {
                switch ($0.time, $1.time) {
                case let (t0?, t1?): return t0 < t1
                case (nil, nil): return $0.timestamp > $1.timestamp
                case (nil, _?): return false
                case (_?, nil): return true
                }
            }
        let calendar = Calendar.current
        var lastEndTime: Date? = nil
        var items: [AnyView] = []
        for task in filteredTasks {
            guard let start = task.time else {
                items.append(AnyView(TaskRow(
                    task: task,
                    currentUserId: currentUserId,
                    sessionCode: sessionCode,
                    onToggleComplete: { viewModel.toggleTaskCompletion(sessionCode: sessionCode, task: task) },
                    isIndividual: mode == .individual,
                    previousUserId: nil,
                    onEdit: { editingTask = task },
                    onDelete: { deleteTaskById(task.id) },
                    onChecklist: { checklistTask = task },
                    onEditChecklist: { editingChecklistTask = task },
                    userName: sessionVM.userIdToUsername[task.userId]
                )))
                continue
            }
            let end = task.endTime ?? calendar.date(byAdding: .hour, value: 1, to: start)!
            if let last = lastEndTime, last < start {
                items.append(AnyView(FreeTimeRow(start: last, end: start)))
            } else if lastEndTime == nil && start > calendar.startOfDay(for: start) {
                let dayStart = calendar.startOfDay(for: start)
                items.append(AnyView(FreeTimeRow(start: dayStart, end: start)))
            }
            items.append(AnyView(TaskRow(
                task: task,
                currentUserId: currentUserId,
                sessionCode: sessionCode,
                onToggleComplete: { viewModel.toggleTaskCompletion(sessionCode: sessionCode, task: task) },
                isIndividual: mode == .individual,
                previousUserId: nil,
                onEdit: { editingTask = task },
                onDelete: { deleteTaskById(task.id) },
                onChecklist: { checklistTask = task },
                onEditChecklist: { editingChecklistTask = task },
                userName: sessionVM.userIdToUsername[task.userId]
            )))
            lastEndTime = end
        }
        if let last = lastEndTime {
            let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: last)!
            if last < dayEnd {
                items.append(AnyView(FreeTimeRow(start: last, end: dayEnd)))
            }
        }
        return items
    }
    
    var body: some View {
        VStack {
            // Меню выбора дня недели с визуализацией статуса дней
            WeekdayPicker(selectedWeekday: $selectedWeekday)
            
            // Кнопка очистки задач за день
            if !viewModel.tasks.filter({ $0.weekday == selectedWeekday }).isEmpty {
                Button(role: .destructive) {
                    showDeleteDayAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Очистить все задачи")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .alert("Удалить все задачи за этот день?", isPresented: $showDeleteDayAlert) {
                    Button("Удалить", role: .destructive) {
                        deleteAllTasksForSelectedDay()
                    }
                    Button("Отмена", role: .cancel) {}
                }
            }
            
            // Список задач, отфильтрованный по дню недели, отсортированный по времени
            List {
                ForEach(Array(timelineItems.enumerated()), id: \.offset) { pair in
                    let view = pair.element
                    view
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Сессия \(sessionCode)")
        // Экран добавления задачи
        .sheet(isPresented: $showAddTask) {
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
            if mode == .individual {
                sessionVM.fetchUsernamesIfNeeded(for: viewModel.tasks)
            }
        }
        .onChange(of: viewModel.tasks) { tasks in
            if mode == .individual {
                sessionVM.fetchUsernamesIfNeeded(for: tasks)
            }
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

    // Функция удаления всех задач за выбранный день
    private func deleteAllTasksForSelectedDay() {
        let dayTasks = viewModel.tasks.filter { $0.weekday == selectedWeekday }
        for task in dayTasks {
            deleteTaskById(task.id)
        }
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
    /// Username пользователя задачи
    let userName: String?
    @State private var isPressed = false
    
    // Новый вычисляемый цвет фона
    var backgroundColor: Color {
        if isIndividual {
            if task.isCompleted || task.status == .done {
                return task.userId == currentUserId ? Color.green.opacity(0.25) : Color.purple.opacity(0.25)
            }
            return task.userId == currentUserId ? Color(.systemBackground) : Color.orange.opacity(0.12)
        } else if task.status == .done {
            return Color.green.opacity(0.18)
        } else if task.status == .snoozed {
            return Color.orange.opacity(0.18)
        } else if task.status == .cancelled {
            return Color.red.opacity(0.18)
        } else if task.isCompleted {
            return Color.green.opacity(0.18)
        } else {
            return Color(.systemGray5)
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Цветной кружок с инициалом пользователя только в индивидуальном режиме
            if isIndividual {
                let isMine = task.userId == currentUserId
                Circle()
                    .fill(isMine ? Color.blue : Color.orange)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(isMine ? "Я" : "2")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            } else {
                // Сохраняем иконку типа задачи для общего режима
                Image(systemName: task.type.icon)
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Иконка выполненной задачи
                    if (task.isCompleted || task.status == .done) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(isIndividual ? (task.userId == currentUserId ? .green : .purple) : .green)
                    }
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(
                            (task.isCompleted || task.status == .done) ?
                                (isIndividual ? (task.userId == currentUserId ? .green : .purple) : .green)
                                : (task.status == .cancelled ? .red : .primary)
                        )
                        .strikethrough(task.isCompleted || task.status == .done || task.status == .cancelled)
                }
                // Подпись под задачей в индивидуальном режиме
                if isIndividual {
                    if task.userId == currentUserId {
                        Text("Вы")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if let name = userName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Другой участник")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
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
                .fill(backgroundColor)
                .shadow(color: isIndividual ? Color(.black).opacity(0.04) : .clear, radius: 2, x: 0, y: 1)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        // Отметка выполнения только для своих задач
        .onTapGesture {
            if task.status != .cancelled && (!isIndividual || task.userId == currentUserId) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = true
                    onToggleComplete()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isPressed = false
                    }
                }
            }
        }
        // SwipeActions только для своих задач
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !isIndividual || task.userId == currentUserId {
                Button(action: {
                    // Отменить задачу (красный)
                    var updatedTask = task
                    updatedTask.status = .cancelled
                    FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                }) {
                    Label("Отменить", systemImage: "xmark.circle")
                }.tint(.red)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isIndividual || task.userId == currentUserId {
                Button(action: {
                    // Отложить задачу (оранжевый)
                    var updatedTask = task
                    updatedTask.status = .snoozed
                    FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                }) {
                    Label("Отложить", systemImage: "clock.arrow.circlepath")
                }.tint(.orange)
            }
        }
        // Контекстное меню только для своих задач (редактировать, удалить)
        .contextMenu {
            if !isIndividual || task.userId == currentUserId {
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

// Добавляю компонент для отображения свободного времени
struct FreeTimeRow: View {
    let start: Date
    let end: Date
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundColor(.gray)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(.systemGray5)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Свободное время")
                    .font(.headline)
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    Text(start, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(end, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
