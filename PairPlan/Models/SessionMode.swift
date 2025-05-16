import Foundation

enum SessionMode: String, Codable {
    case shared
    case individual
    
    var description: String {
        switch self {
        case .shared:
            return "Общий режим"
        case .individual:
            return "Индивидуальный режим"
        }
    }
    
    var icon: String {
        switch self {
        case .shared:
            return "person.2.fill"
        case .individual:
            return "person.fill"
        }
    }
} 