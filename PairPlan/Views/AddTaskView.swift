// File: Views/AddTaskView.swift
import SwiftUI
import PhotosUI
import UserNotifications

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// Экран добавления новой задачи. Позволяет ввести название, описание, выбрать тип, время, чеклист и день недели.
struct AddTaskView: View {
    let sessionCode: String
    let mode: SessionMode
    let selectedWeekday: Int
    var existingTasks: [Task] = [] // Передавайте сюда задачи на выбранный день
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTaskViewModel()
    @State private var descriptionText: String = ""
    @State private var selectedTime: Date = Date()
    @State private var selectedEndTime: Date = Date().addingTimeInterval(3600) // +1 hour by default
    @State private var useTime: Bool = false
    @State private var useEndTime: Bool = false
    @State private var checklist: [ChecklistItem] = []
    @State private var showChecklistEditor = false
    @State private var showTimeConflictAlert = false
    @State private var showNotificationPermissionAlert = false

    init(sessionCode: String, mode: SessionMode, defaultWeekday: Int, existingTasks: [Task] = []) {
        self.sessionCode = sessionCode
        self.mode = mode
        self.selectedWeekday = defaultWeekday
        self.existingTasks = existingTasks
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Детали задачи")) {
                    TextField("Название", text: $viewModel.title)
                        .submitLabel(.done)
                        .onSubmit {
                            hideKeyboard()
                        }
                    
                    Picker("Тип", selection: $viewModel.selectedType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.description, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                Section(header: Text("Описание")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 60)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Готово") {
                                    hideKeyboard()
                                }
                            }
                        }
                }
                Section(header: Text("Время")) {
                    Toggle("Установить время", isOn: $useTime)
                    if useTime {
                        DatePicker("Начало", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                        Toggle("Установить время окончания", isOn: $useEndTime)
                        if useEndTime {
                            DatePicker("Окончание", selection: $selectedEndTime, displayedComponents: [.hourAndMinute])
                                .onChange(of: selectedTime) { newTime in
                                    // Если время начала больше времени окончания, обновляем время окончания
                                    if newTime > selectedEndTime {
                                        selectedEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: newTime) ?? newTime
                                    }
                                }
                        }
                    }
                }
                Section(header: Text("Чеклист")) {
                    if checklist.isEmpty {
                        Button("Добавить чеклист") { showChecklistEditor = true }
                    } else {
                        ForEach(checklist) { item in
                            HStack {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                Text(item.text)
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(item.isCompleted ? .gray : .primary)
                            }
                        }
                        Button("Редактировать чеклист") { showChecklistEditor = true }
                    }
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        if useTime {
                            let newStart = selectedTime
                            let newEnd = useEndTime ? selectedEndTime : Calendar.current.date(byAdding: .hour, value: 1, to: selectedTime) ?? selectedTime
                            if !isTimeSlotAvailable(newStart: newStart, newEnd: newEnd, existingTasks: existingTasks) {
                                showTimeConflictAlert = true
                                return
                            }
                        }
                        
                        // Проверяем статус разрешения на уведомления
                        UNUserNotificationCenter.current().getNotificationSettings { settings in
                            DispatchQueue.main.async {
                                switch settings.authorizationStatus {
                                case .notDetermined:
                                    // Запрашиваем разрешение
                                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                                        if granted {
                                            scheduleNotification()
                                        }
                                    }
                                case .authorized:
                                    // Разрешение уже получено
                                    scheduleNotification()
                                case .denied:
                                    // Показываем алерт с предложением открыть настройки
                                    showNotificationPermissionAlert = true
                                default:
                                    break
                                }
                            }
                        }
                        
                        viewModel.addTask(
                            sessionCode: sessionCode,
                            mode: mode,
                            description: descriptionText.isEmpty ? nil : descriptionText,
                            time: useTime ? selectedTime : nil,
                            endTime: useTime && useEndTime ? selectedEndTime : nil,
                            checklist: checklist.isEmpty ? nil : checklist,
                            weekday: selectedWeekday
                        )
                        dismiss()
                    }
                    .disabled(viewModel.title.isEmpty)
                }
            }
            .alert("На это время уже есть задача!", isPresented: $showTimeConflictAlert) {
                Button("Ок", role: .cancel) {}
            }
            .alert("Нет доступа к уведомлениям", isPresented: $showNotificationPermissionAlert) {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Для получения уведомлений о задачах, пожалуйста, разрешите доступ к уведомлениям в настройках приложения.")
            }
        }
        .sheet(isPresented: $showChecklistEditor) {
            ChecklistEditorView(checklist: $checklist)
        }
    }

    // Функция для планирования уведомления
    private func scheduleNotification() {
        print("Планирую уведомление...")
        let content = UNMutableNotificationContent()
        content.title = viewModel.title
        content.body = descriptionText.isEmpty ? "Время выполнить задачу" : descriptionText
        content.sound = .default
        
        // Преобразуем пользовательский индекс дня недели в формат iOS
        // В приложении: 1 — понедельник, 7 — воскресенье
        // В iOS: 1 — воскресенье, 7 — суббота
        let iosWeekday = selectedWeekday == 7 ? 1 : selectedWeekday + 1
        
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: useTime ? selectedTime : Date())
        dateComponents.weekday = iosWeekday
        if !useTime {
            dateComponents.hour = 9
            dateComponents.minute = 0
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "\(sessionCode)_\(viewModel.title)_\(selectedWeekday)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка при добавлении уведомления: \(error)")
            } else {
                print("Уведомление успешно добавлено: \(identifier)")
            }
        }
    }

    // Возвращает номер текущей недели в году
    func getCurrentWeekNumber() -> Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }

    // Возвращает текущий год
    func getCurrentYear() -> Int {
        Calendar.current.component(.year, from: Date())
    }

    // Проверка на пересечение задач
    func isTimeSlotAvailable(newStart: Date, newEnd: Date, existingTasks: [Task]) -> Bool {
        let calendar = Calendar.current
        
        // Получаем только время (часы и минуты) из дат
        let newStartComponents = calendar.dateComponents([.hour, .minute], from: newStart)
        let newEndComponents = calendar.dateComponents([.hour, .minute], from: newEnd)
        
        // Преобразуем время в минуты для удобства сравнения
        let newStartMinutes = (newStartComponents.hour ?? 0) * 60 + (newStartComponents.minute ?? 0)
        let newEndMinutes = (newEndComponents.hour ?? 0) * 60 + (newEndComponents.minute ?? 0)
        
        // Проверяем, что время окончания больше времени начала
        if newEndMinutes <= newStartMinutes {
            return false
        }
        
        // Проверяем, является ли новая задача задачей с интервалом
        let isNewTaskWithInterval = newEndMinutes != newStartMinutes + 60
        
        for task in existingTasks {
            guard let start = task.time else { continue }
            
            // Получаем компоненты времени для существующей задачи
            let existingStartComponents = calendar.dateComponents([.hour, .minute], from: start)
            let existingStartMinutes = (existingStartComponents.hour ?? 0) * 60 + (existingStartComponents.minute ?? 0)
            
            // Проверяем, является ли существующая задача задачей с интервалом
            if let end = task.endTime {
                let existingEndComponents = calendar.dateComponents([.hour, .minute], from: end)
                let existingEndMinutes = (existingEndComponents.hour ?? 0) * 60 + (existingEndComponents.minute ?? 0)
                
                // Если новая задача без интервала
                if !isNewTaskWithInterval {
                    // Проверяем, не попадает ли время новой задачи в интервал существующей
                    if newStartMinutes >= existingStartMinutes && newStartMinutes < existingEndMinutes {
                        return false
                    }
                } else {
                    // Если новая задача с интервалом
                    // Проверяем, не пересекается ли новый интервал с существующим
                    if (newStartMinutes < existingEndMinutes && newEndMinutes > existingStartMinutes) {
                        return false
                    }
                }
            } else {
                // Если существующая задача без интервала
                if !isNewTaskWithInterval {
                    // Если обе задачи без интервала, проверяем совпадение времени
                    if newStartMinutes == existingStartMinutes {
                        return false
                    }
                } else {
                    // Если новая задача с интервалом, проверяем, не попадает ли существующая задача в новый интервал
                    if newStartMinutes >= existingStartMinutes && newStartMinutes < newEndMinutes {
                        return false
                    }
                }
            }
        }
        return true
    }
}
