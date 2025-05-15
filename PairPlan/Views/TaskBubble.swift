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
                    .foregroundColor(task.isCompleted ? .completedColor : .textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: task.type.icon)
                        .font(.caption)
                        .foregroundColor(task.type.color)
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .textSecondary : .textPrimary)
                        .lineLimit(2)
                }
                if let desc = task.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.top, 2)
                }
                if let checklist = task.checklist, !checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(checklist) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .font(.caption2)
                                    .foregroundColor(item.isCompleted ? .accentColor : .textSecondary)
                                Text(item.text)
                                    .font(.caption2)
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(item.isCompleted ? .textSecondary : .textPrimary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                if let date = task.timestamp {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(date, style: .time)
                            .font(.caption2)
                    }
                    .foregroundColor(.textSecondary)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
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
