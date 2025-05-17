import Foundation

class AddTaskViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedType: TaskType = .other
    
    func addTask(sessionCode: String, mode: SessionMode, description: String? = nil, time: Date? = nil, checklist: [ChecklistItem]? = nil, weekday: Int) {
        let task = Task(
            title: title,
            type: selectedType,
            userId: UserDefaults.standard.string(forKey: "PairPlan.currentUserId") ?? UUID().uuidString,
            timestamp: Date(),
            weekday: weekday,
            description: description,
            time: time,
            checklist: checklist
        )
        
        FirestoreManager.shared.addTask(sessionCode: sessionCode, task: task) { error in
            if let error = error {
                print("Error adding task: \(error.localizedDescription)")
            }
        }
    }
} 
