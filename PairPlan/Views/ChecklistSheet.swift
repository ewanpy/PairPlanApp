import SwiftUI
import Foundation

struct ChecklistEditorView: View {
    @Binding var checklist: [ChecklistItem]
    @Environment(\.presentationMode) var presentationMode
    @State private var newItemText: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach($checklist) { $item in
                    HStack {
                        TextField("Текст пункта", text: $item.text)
                    }
                }
                .onDelete { indices in
                    checklist.remove(atOffsets: indices)
                }
                HStack {
                    TextField("Новый пункт", text: $newItemText)
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Чеклист")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.endEditing()
                    }
                }
            }
        }
    }
    
    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        checklist.append(ChecklistItem(text: trimmed, isCompleted: false))
        newItemText = ""
    }
}

// Экран просмотра и отметки чеклиста задачи. Если isReadOnly == true, чеклист только для просмотра.
struct ChecklistMarkView: View {
    @Binding var checklist: [ChecklistItem]
    @Environment(\.presentationMode) var presentationMode
    var isReadOnly: Bool = false
    var body: some View {
        NavigationView {
            List {
                ForEach($checklist) { $item in
                    Button(action: {
                        if !isReadOnly {
                            item.isCompleted.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isCompleted ? .green : .gray)
                            Text(item.text)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                        }
                    }
                    .disabled(isReadOnly)
                    .opacity(isReadOnly ? 0.6 : 1.0)
                }
            }
            .navigationTitle("Чеклист задачи")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Extension для скрытия клавиатуры
import UIKit
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
