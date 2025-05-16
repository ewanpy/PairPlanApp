import Foundation
import SwiftUI
import FirebaseFirestore

struct ChecklistItem: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var isCompleted: Bool
}

struct Task: Identifiable, Codable {
    var id: String
    var title: String
    var type: TaskType
    var userId: String
    var timestamp: Date
    var isCompleted: Bool
    var description: String?
    var time: Date?
    var checklist: [ChecklistItem]?
    
    init(id: String = UUID().uuidString,
         title: String,
         type: TaskType,
         userId: String,
         timestamp: Date = Date(),
         isCompleted: Bool = false,
         description: String? = nil,
         time: Date? = nil,
         checklist: [ChecklistItem]? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.userId = userId
        self.timestamp = timestamp
        self.isCompleted = isCompleted
        self.description = description
        self.time = time
        self.checklist = checklist
    }
}
