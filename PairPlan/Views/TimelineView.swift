import SwiftUI

struct TimelineView: View {
    let tasks: [Task]
    let selectedWeekday: Int
    let startHour: Int = 0 // Сетка с 0:00
    let endHour: Int = 24  // до 24:00 (не включая)
    let hourHeight: CGFloat = 60
    
    private var hourRange: [Int] {
        Array(startHour..<endHour)
    }
    
    private var filteredTasks: [Task] {
        tasks.filter { $0.weekday == selectedWeekday }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredTasks) { task in
                    TaskTimelineBlockSimple(task: task)
                }
            }
            .padding(.top, 16)
        }
    }
}

struct TaskTimelineBlockSimple: View {
    let task: Task
    var body: some View {
        HStack {
            Image(systemName: task.type.icon)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(task.title)
                    .font(.subheadline)
                    .bold()
                if let description = task.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let time = task.time {
                    Text(time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                if let endTime = task.endTime {
                    Text("— " + endTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
