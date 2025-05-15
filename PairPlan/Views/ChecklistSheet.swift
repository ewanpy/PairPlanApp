import SwiftUI
import Foundation

struct ChecklistSheet: View, Identifiable {
    let id = UUID()
    @State var task: Task
    var onSave: (Task) -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                if let checklist = task.checklist {
                    ForEach(checklist.indices, id: \ .self) { idx in
                        HStack {
                            Button(action: {
                                task.checklist?[idx].isCompleted.toggle()
                            }) {
                                Image(systemName: task.checklist?[idx].isCompleted == true ? "checkmark.square.fill" : "square")
                                    .foregroundColor(task.checklist?[idx].isCompleted == true ? .accentColor : .secondary)
                            }
                            Text(task.checklist?[idx].text ?? "")
                        }
                    }
                } else {
                    Text("Нет пунктов чеклиста")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Чеклист задачи")
            .navigationBarItems(trailing: Button("Готово") {
                onSave(task)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 