import SwiftUI
import Foundation

struct TaskRow: View {
    let task: Task
    let mode: SessionMode
    let currentUserId: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let action: () -> Void
    let onChecklist: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .disabled(mode == .individual && task.ownerId != currentUserId)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: task.type.icon)
                        .foregroundColor(.accentColor)
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
                }
                if let desc = task.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let checklist = task.checklist, !checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(checklist) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .font(.caption2)
                                    .foregroundColor(item.isCompleted ? .accentColor : .secondary)
                                Text(item.text)
                                    .font(.caption2)
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(item.isCompleted ? .gray : .primary)
                            }
                        }
                    }
                }
                if let date = task.timestamp {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(date, style: .time)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            if task.ownerId == currentUserId {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            if mode == .shared {
                Image(systemName: task.ownerId == currentUserId ? "person.fill" : "person.2.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
        .if(mode == .individual && task.ownerId == currentUserId) { view in
            view.onTapGesture { onEdit() }
        }
        .contextMenu {
            if task.ownerId == currentUserId {
                Button(action: onEdit) {
                    Label("Редактировать", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            }
            Button(action: onChecklist) {
                Label("Чеклист", systemImage: "checklist")
            }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 