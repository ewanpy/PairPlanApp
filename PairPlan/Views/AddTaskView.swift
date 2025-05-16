// File: Views/AddTaskView.swift
import SwiftUI
import PhotosUI

struct AddTaskView: View {
    let sessionCode: String
    let mode: SessionMode
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTaskViewModel()
    @State private var descriptionText: String = ""
    @State private var selectedTime: Date = Date()
    @State private var useTime: Bool = false
    @State private var checklist: [ChecklistItem] = []
    @State private var showChecklistEditor = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Детали задачи")) {
                    TextField("Название", text: $viewModel.title)
                    
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
                        viewModel.addTask(
                            sessionCode: sessionCode,
                            mode: mode,
                            description: descriptionText.isEmpty ? nil : descriptionText,
                            time: useTime ? selectedTime : nil,
                            checklist: checklist.isEmpty ? nil : checklist
                        )
                        dismiss()
                    }
                    .disabled(viewModel.title.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showChecklistEditor) {
            ChecklistEditorView(checklist: $checklist)
        }
    }
}
