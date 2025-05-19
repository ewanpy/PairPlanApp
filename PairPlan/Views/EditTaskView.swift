import SwiftUI
import Foundation

// Экран редактирования существующей задачи. Позволяет изменить основные параметры задачи и сохранить изменения.
struct EditTaskView: View {
    let task: Task
    let onSave: (Task) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var selectedType: TaskType
    @State private var descriptionText: String
    @State private var useTime: Bool
    @State private var selectedTime: Date
    @State private var checklist: [ChecklistItem]
    @State private var showChecklistEditor = false

    @Environment(\.presentationMode) private var presentationMode

    init(task: Task, onSave: @escaping (Task) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _date = State(initialValue: task.timestamp)
        _selectedType = State(initialValue: task.type)
        _descriptionText = State(initialValue: task.description ?? "")
        _useTime = State(initialValue: task.time != nil)
        _selectedTime = State(initialValue: task.time ?? task.timestamp)
        _checklist = State(initialValue: task.checklist ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Редактировать задачу")) {
                    TextField("Название задачи", text: $title)
                    Picker("Тип задачи", selection: $selectedType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.description, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                Section(header: Text("Описание")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 60)
                }
                Section(header: Text("Время")) {
                    Toggle("Установить время", isOn: $useTime)
                    if useTime {
                        DatePicker("Время", selection: $selectedTime, displayedComponents: [.hourAndMinute])
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
                        Button("Чеклист") { showChecklistEditor = true }
                    }
                }
            }
            .navigationBarTitle("Редактировать задачу", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Сохранить") {
                    let updatedTask = Task(
                        id: task.id,
                        title: title,
                        type: selectedType,
                        userId: task.userId,
                        timestamp: task.timestamp,
                        weekday: task.weekday,
                        isCompleted: task.isCompleted,
                        description: descriptionText.isEmpty ? nil : descriptionText,
                        time: useTime ? selectedTime : nil,
                        checklist: checklist.isEmpty ? nil : checklist
                    )
                    onSave(updatedTask)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }
} 

