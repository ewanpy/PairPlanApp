import Foundation

enum TaskType: String, CaseIterable, Codable {
    case work
    case personal
    case shopping
    case health
    case education
    case other
    
    var description: String {
        switch self {
        case .work:
            return "Работа"
        case .personal:
            return "Личное"
        case .shopping:
            return "Покупки"
        case .health:
            return "Здоровье"
        case .education:
            return "Обучение"
        case .other:
            return "Другое"
        }
    }
    
    var icon: String {
        switch self {
        case .work:
            return "briefcase.fill"
        case .personal:
            return "person.fill"
        case .shopping:
            return "cart.fill"
        case .health:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
} 