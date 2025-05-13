import Foundation

struct Task: Identifiable {
    var id: String
    var title: String
    var timestamp: Date?
    var isCompleted: Bool
    var ownerId: String   // UUID создателя задачи
}
