import SwiftUI
import Foundation

struct TaskBubble: View {
    let task: Task
    let isCurrentUser: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let action: () -> Void
    let onChecklist: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 32)
            }
            Button(action: action) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: task.type.icon)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
                        .lineLimit(2)
                }
                if let date = task.timestamp as Date? {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(date, style: .time)
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .contextMenu {
                if isCurrentUser {
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
            if !isCurrentUser {
                Spacer(minLength: 32)
            }
        }
    }
} 
