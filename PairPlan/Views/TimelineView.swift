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
            .sorted { task1, task2 in
                guard let time1 = task1.time, let time2 = task2.time else {
                    return false
                }
                return time1 < time2
            }
    }
    
    private func getFreeTimeSlots() -> [(start: Date, end: Date)] {
        var freeSlots: [(start: Date, end: Date)] = []
        let calendar = Calendar.current
        
        // Создаем начальную и конечную точки дня
        var currentDate = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: currentDate)!
        
        // Если нет задач, весь день свободен
        if filteredTasks.isEmpty {
            return [(currentDate, endOfDay)]
        }
        
        // Проверяем время до первой задачи
        if let firstTaskTime = filteredTasks.first?.time {
            if currentDate < firstTaskTime {
                freeSlots.append((currentDate, firstTaskTime))
            }
        }
        
        // Проверяем промежутки между задачами
        for i in 0..<filteredTasks.count - 1 {
            let currentTask = filteredTasks[i]
            let nextTask = filteredTasks[i + 1]
            
            if let currentEndTime = currentTask.endTime ?? currentTask.time?.addingTimeInterval(3600),
               let nextStartTime = nextTask.time {
                if currentEndTime < nextStartTime {
                    freeSlots.append((currentEndTime, nextStartTime))
                }
            }
        }
        
        // Проверяем время после последней задачи
        if let lastTask = filteredTasks.last,
           let lastTaskEndTime = lastTask.endTime ?? lastTask.time?.addingTimeInterval(3600) {
            if lastTaskEndTime < endOfDay {
                freeSlots.append((lastTaskEndTime, endOfDay))
            }
        }
        
        return freeSlots
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Отображаем свободные промежутки времени
                ForEach(getFreeTimeSlots(), id: \.start) { slot in
                    FreeTimeSlotView(startTime: slot.start, endTime: slot.end)
                }
                
                // Отображаем задачи
                ForEach(filteredTasks) { task in
                    TaskTimelineBlockSimple(task: task)
                }
            }
            .padding(.top, 16)
        }
    }
}

struct FreeTimeSlotView: View {
    let startTime: Date
    let endTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                Text("Свободное время")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            HStack {
                Text(startTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("—")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(endTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .opacity(0.5)
        )
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
                .fill(Color(.systemGray5))
        )
    }
}
