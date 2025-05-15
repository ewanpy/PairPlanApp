import Foundation
import SwiftUI

struct ChecklistItem: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var isCompleted: Bool
}

enum TaskType: String, Codable {
    case work
    case study
    case personal
    case other
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .personal: return "person.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return .workColor
        case .study: return .studyColor
        case .personal: return .personalColor
        case .other: return .otherColor
        }
    }
}

struct Task: Identifiable {
    var id: String
    var title: String
    var timestamp: Date?
    var isCompleted: Bool
    var ownerId: String   // UUID создателя задачи
    var type: TaskType    // Тип задачи
    var color: String?    // Hex color string or name
    var description: String?
    var attachments: [String]? // URLs to files/images
    var repeatRule: String?    // e.g., "none", "daily", "weekly", "custom"
    var checklist: [ChecklistItem]?
}
