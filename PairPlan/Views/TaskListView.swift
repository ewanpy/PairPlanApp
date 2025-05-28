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
    /// View mode picker
    @State private var viewMode: TaskViewMode = .list
    
    var body: some View {
        VStack {
            // View mode picker
            Picker("Режим отображения", selection: $viewMode) {
                Image(systemName: "list.bullet")
                    .tag(TaskViewMode.list)
                Image(systemName: "clock")
                    .tag(TaskViewMode.timeline)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if viewMode == .list {
                // Меню выбора дня недели с визуализацией статуса дней
                WeekdayPicker(selectedWeekday: $selectedWeekday)
                // Список задач, отфильтрованный по дню недели, отсортированный по времени
                List {
                    // Фильтрация и сортировка задач
                    let filteredTasks = viewModel.tasks
                        .filter { $0.weekday == selectedWeekday }
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.toggleTaskCompletion(sessionCode: sessionCode, task: task)
                                }
                            },
                            isIndividual: mode == .individual,
                            previousUserId: prevUserId,
                            onEdit: {
                                editingTask = task
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
            } else {
                TimelineView(tasks: viewModel.tasks)
            }
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
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task) { updatedTask in
                FirestoreManager.shared.addTask(sessionCode: sessionCode, task: updatedTask) { _ in }
                editingTask = nil // Закрыть sheet после сохранения
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

// Строка задачи в списке. Отвечает за отображение задачи, анимацию, контекстное меню и визуализацию статуса задачи.
struct TaskRow: View {
    /// Задача, которую отображает строка
    let task: Task
    /// ID текущего пользователя (для определения владельца задачи)
    let currentUserId: String
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
    /// Состояние анимации нажатия
    @State private var isPressed = false
    /// Состояние долгого нажатия (для подсветки)
    @State private var isLongPressed = false

    /// Является ли задача задачей текущего пользователя
    var isCurrentUser: Bool { task.userId == currentUserId }
    /// Цвет фона "пузыря" задачи в зависимости от статуса и владельца
    var bubbleColor: Color {
        if isIndividual {
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
        } else {
            // В режиме shared цвет всегда одинаковый для всех
            return task.isCompleted ? Color.green.opacity(0.13) : Color(.systemGray6)
        }
    }
    /// Цвет текста задачи
    var textColor: Color {
        if isIndividual {
            if task.isCompleted && !isCurrentUser {
                return .primary
            } else {
                return isCurrentUser ? .primary : .white
            }
        } else {
            // В режиме shared цвет текста всегда одинаковый для всех
            return task.isCompleted ? .gray : .primary
        }
    }
    /// Выравнивание пузыря (слева для своих, справа для чужих)
    var alignment: Alignment { isCurrentUser ? .leading : .trailing }
    /// Высота пузыря
    var bubbleHeight: CGFloat { isIndividual ? 42 : 50 }
    /// Размер шрифта
    var fontSize: CGFloat { isIndividual ? 17 : 20 }
    /// Размер иконки чекбокса
    var circleSize: CGFloat { isIndividual ? 20 : 24 }
    /// Горизонтальный паддинг
    var horizontalPadding: CGFloat { isIndividual ? 14 : 20 }
    /// Вертикальный отступ между задачами
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
        if isIndividual {
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
        } else {
            Button(action: {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isPressed = false
                    onToggleComplete()
                }
            }) {
                bubbleContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
    }

    /// Основное содержимое пузыря задачи: заголовок, описание, чеклист, время
    private var bubbleContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                // Заголовок и статус выполнения
                HStack(alignment: .top, spacing: 6) {
                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: fontSize + 2))
                    }
                    Text(task.title)
                        .font(.system(size: fontSize + 2, weight: .bold))
                }
                // Описание задачи (если есть)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: fontSize - 2))
                }
                // Превью чеклиста (до 3 пунктов)
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
                // Время задачи (если есть)
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
            .frame(maxWidth: isIndividual ? 280 : .infinity, alignment: .leading)
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
        // Подсветка при долгом нажатии
        .onLongPressGesture(minimumDuration: 0.15, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isLongPressed = pressing
            }
        }, perform: {})
        // Контекстное меню для действий над задачей
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

enum TaskViewMode {
    case list
    case timeline
}
