import SwiftUI

struct TimelineView: View {
    let tasks: [Task]
    let startHour: Int = 0
    let endHour: Int = 24
    
    private var hourRange: [Int] {
        Array(startHour..<endHour)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(hourRange, id: \.self) { hour in
                    TimelineHourRow(hour: hour, tasks: tasksForHour(hour))
                }
            }
        }
    }
    
    private func tasksForHour(_ hour: Int) -> [Task] {
        tasks.filter { task in
            guard let taskTime = task.time else { return false }
            let calendar = Calendar.current
            let taskHour = calendar.component(.hour, from: taskTime)
            return taskHour == hour
        }
    }
}

struct TimelineHourRow: View {
    let hour: Int
    let tasks: [Task]
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .frame(width: 50)
                .padding(.top, 8)
            
            // Vertical line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .frame(height: 60)
            
            // Tasks for this hour
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tasks) { task in
                    TaskTimelineItem(task: task)
                }
            }
            .padding(.leading, 8)
            
            Spacer()
        }
        .frame(height: max(60, CGFloat(tasks.count * 60)))
    }
}

struct TaskTimelineItem: View {
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
            }
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    TimelineView(tasks: [
        Task(title: "Встреча", type: .work, userId: "1", weekday: 1, time: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())),
        Task(title: "Обед", type: .personal, userId: "1", weekday: 1, time: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())),
        Task(title: "Тренировка", type: .health, userId: "1", weekday: 1, time: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()))
    ])
} 