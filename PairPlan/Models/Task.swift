import Foundation
import SwiftUI
import FirebaseFirestore

struct ChecklistItem: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var isCompleted: Bool
}

enum TaskStatus: String, Codable {
    case normal
    case snoozed
    case cancelled
    case done
}

struct Task: Identifiable, Codable {
    var id: String
    var title: String
    var type: TaskType
    var userId: String
    var timestamp: Date
    var weekday: Int     // 1 (Пн) - 7 (Вс)
    var isCompleted: Bool
    var description: String?
    var time: Date?
    var endTime: Date?   // Время окончания задачи
    var checklist: [ChecklistItem]?
    var status: TaskStatus = .normal
    
    init(id: String = UUID().uuidString,
         title: String,
         type: TaskType,
         userId: String,
         timestamp: Date = Date(),
         weekday: Int,
         isCompleted: Bool = false,
         description: String? = nil,
         time: Date? = nil,
         endTime: Date? = nil,
         checklist: [ChecklistItem]? = nil,
         status: TaskStatus = .normal) {
        self.id = id
        self.title = title
        self.type = type
        self.userId = userId
        self.timestamp = timestamp
        self.weekday = weekday
        self.isCompleted = isCompleted
        self.description = description
        self.time = time
        self.endTime = endTime
        self.checklist = checklist
        self.status = status
    }
}
