import SwiftUI
import Foundation
import PhotosUI

struct EditTaskView: View {
    let task: Task
    let onSave: (Task) -> Void
    
    @State private var title: String
    @State private var date: Date
    @State private var useTime: Bool
    @State private var selectedType: TaskType
    @State private var color: Color
    @State private var descriptionText: String
    @State private var attachments: [UIImage]
    @State private var repeatRule: String
    @State private var checklist: [ChecklistItem]
    @State private var newChecklistText: String = ""
    @State private var showImagePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    @Environment(\.presentationMode) private var presentationMode
    
    init(task: Task, onSave: @escaping (Task) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _date = State(initialValue: task.timestamp ?? Date())
        _useTime = State(initialValue: task.timestamp != nil)
        _selectedType = State(initialValue: task.type)
        _color = State(initialValue: Color(hex: task.color) ?? .accentColor)
        _descriptionText = State(initialValue: task.description ?? "")
        _attachments = State(initialValue: []) // For real app, load images from URLs
        _repeatRule = State(initialValue: task.repeatRule ?? "none")
        _checklist = State(initialValue: task.checklist ?? [])
    }
    
    var body: some View {
        NavigationView {
            Form {
                editSection
                descriptionSection
                attachmentsSection
                repeatSection
                checklistSection
                timeSection
            }
            .navigationBarTitle("Редактировать задачу", displayMode: .inline)
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotos, maxSelectionCount: 3, matching: .images)
            .onChange(of: selectedPhotos) { newItems in
                for item in newItems {
                    item.loadTransferable(type: Data.self) { result in
                        if let data = try? result.get(), let image = UIImage(data: data) {
                            attachments.append(image)
                        }
                    }
                }
            }
            .toolbar { keyboardToolbar }
        }
    }
    
    private var editSection: some View {
        Section(header: Text("Редактировать задачу")) {
            TextField("Название задачи", text: $title)
            Picker("Тип задачи", selection: $selectedType) {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }
            ColorPicker("Цвет задачи", selection: $color)
        }
    }
    
    private var descriptionSection: some View {
        Section(header: Text("Описание")) {
            TextEditor(text: $descriptionText)
                .frame(minHeight: 60)
        }
    }
    
    private var attachmentsSection: some View {
        Section(header: Text("Вложения")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(attachments, id: \.self) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "plus")
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    private var repeatSection: some View {
        Section(header: Text("Повторение")) {
            Picker("Повторять", selection: $repeatRule) {
                Text("Нет").tag("none")
                Text("Каждый день").tag("daily")
                Text("Каждую неделю").tag("weekly")
                Text("Каждый месяц").tag("monthly")
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var checklistSection: some View {
        Section(header: Text("Чеклист")) {
            ForEach(checklist) { item in
                HStack {
                    Button(action: {
                        if let idx = checklist.firstIndex(where: { $0.id == item.id }) {
                            checklist[idx].isCompleted.toggle()
                        }
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(item.isCompleted ? .accentColor : .secondary)
                    }
                    Text(item.text)
                    Spacer()
                    Button(action: {
                        checklist.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            HStack {
                TextField("Добавить пункт", text: $newChecklistText)
                Button("+") {
                    let trimmed = newChecklistText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    checklist.append(ChecklistItem(text: trimmed, isCompleted: false))
                    newChecklistText = ""
                }
            }
        }
    }
    
    private var timeSection: some View {
        Section {
            Toggle("Указать время", isOn: $useTime)
            if useTime {
                DatePicker("Время", selection: $date, displayedComponents: .hourAndMinute)
            }
        }
    }
    
    private var cancelButton: some View {
        Button("Отмена") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private var saveButton: some View {
        Button("Сохранить") {
            var updatedTask = task
            updatedTask.title = title
            updatedTask.timestamp = useTime ? date : nil
            updatedTask.type = selectedType
            updatedTask.color = color.toHex
            updatedTask.description = descriptionText.isEmpty ? nil : descriptionText
            updatedTask.repeatRule = repeatRule == "none" ? nil : repeatRule
            updatedTask.checklist = checklist.isEmpty ? nil : checklist
            // For attachments, you would upload images and get URLs in a real app
            onSave(updatedTask)
        }
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Готово") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }
} 

