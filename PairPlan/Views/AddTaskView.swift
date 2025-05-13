// File: Views/AddTaskView.swift
import SwiftUI

struct AddTaskView: View {
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var useTime: Bool = false

    @Environment(\.presentationMode) private var presentationMode
    var onSave: (String, Date?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Новая задача")) {
                    TextField("Название задачи", text: $title)
                }
                Section {
                    Toggle("Указать время", isOn: $useTime)
                    if useTime {
                        DatePicker("Время", selection: $date, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationBarTitle("Добавить задачу", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Сохранить") {
                    onSave(title, useTime ? date : nil)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            // кнопка «Готово» над клавиатурой
            .toolbar {
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
    }
}
