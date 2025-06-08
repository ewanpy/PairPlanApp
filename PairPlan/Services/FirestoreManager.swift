// File: Services/FirestoreManager.swift
import Foundation
import FirebaseFirestore

// Синглтон для работы с Firestore (создание, загрузка, удаление задач и сессий)
class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Создаёт новую сессию
    func createSession(code: String, mode: SessionMode, ownerId: String, completion: @escaping (Error?) -> Void) {
        let sessionData: [String: Any] = [
            "code": code,
            "mode": mode.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "participants": [],
            "ownerId": ownerId
        ]
        
        db.collection("sessions").document(code).setData(sessionData) { error in
            completion(error)
        }
    }
    
    /// Проверяет, существует ли сессия
    func sessionExists(code: String, completion: @escaping (Bool) -> Void) {
        db.collection("sessions").document(code).getDocument { snapshot, error in
            completion(snapshot?.exists ?? false)
        }
    }
    
    func loadSessionMode(code: String, completion: @escaping (SessionMode?) -> Void) {
        db.collection("sessions").document(code).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let modeString = data["mode"] as? String,
                  let mode = SessionMode(rawValue: modeString) else {
                completion(nil)
                return
            }
            completion(mode)
        }
    }
    
    func addParticipant(sessionCode: String, userId: String, isIndividual: Bool, completion: @escaping (Bool, Error?) -> Void) {
        let sessionRef = db.collection("sessions").document(sessionCode)
        
        db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(sessionRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var participants = snapshot.data()?["participants"] as? [String] else {
                let error = NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid session data"])
                errorPointer?.pointee = error
                return nil
            }
            
            // Check if user is already a participant
            if participants.contains(userId) {
                return nil
            }
            
            // Add user to participants
            participants.append(userId)
            transaction.updateData(["participants": participants], forDocument: sessionRef)
            
            return nil
        } completion: { _, error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
    
    func removeParticipant(sessionCode: String, userId: String, completion: @escaping (Error?) -> Void) {
        let sessionRef = db.collection("sessions").document(sessionCode)
        
        db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(sessionRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var participants = snapshot.data()?["participants"] as? [String] else {
                let error = NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid session data"])
                errorPointer?.pointee = error
                return nil
            }
            
            participants.removeAll { $0 == userId }
            transaction.updateData(["participants": participants], forDocument: sessionRef)
            
            return nil
        } completion: { _, error in
            completion(error)
        }
    }
    
    /// Загружает сессии только для конкретного пользователя
    func loadSessions(for userId: String, completion: @escaping ([Session]) -> Void) {
        db.collection("sessions").whereField("ownerId", isEqualTo: userId).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            let sessions = documents.compactMap { doc -> Session? in
                let data = doc.data()
                guard let code = data["code"] as? String,
                      let modeString = data["mode"] as? String,
                      let mode = SessionMode(rawValue: modeString),
                      let ownerId = data["ownerId"] as? String else { return nil }
                return Session(code: code, mode: mode, ownerId: ownerId)
            }
            completion(sessions)
        }
    }
    
    // MARK: - Task Management
    
    /// Добавляет задачу в Firestore
    func addTask(sessionCode: String, task: Task, completion: @escaping (Error?) -> Void) {
        var taskData: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "type": task.type.rawValue,
            "userId": task.userId,
            "timestamp": task.timestamp,
            "isCompleted": task.isCompleted,
            "weekday": task.weekday,
            "status": task.status.rawValue
        ]
        if let description = task.description {
            taskData["description"] = description
        }
        if let time = task.time {
            taskData["time"] = time
        }
        if let endTime = task.endTime {
            taskData["endTime"] = endTime
        }
        if let checklist = task.checklist {
            taskData["checklist"] = checklist.map { [
                "id": $0.id,
                "text": $0.text,
                "isCompleted": $0.isCompleted
            ] }
        }
        
        db.collection("sessions").document(sessionCode)
            .collection("tasks").document(task.id)
            .setData(taskData) { error in
                completion(error)
            }
    }
    
    /// Загружает задачи из Firestore для сессии
    func loadTasks(sessionCode: String, completion: @escaping ([Task]) -> Void) {
        db.collection("sessions").document(sessionCode)
            .collection("tasks")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let tasks = documents.compactMap { document -> Task? in
                    let data = document.data()
                    guard let id = data["id"] as? String,
                          let title = data["title"] as? String,
                          let typeString = data["type"] as? String,
                          let type = TaskType(rawValue: typeString),
                          let userId = data["userId"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                          let isCompleted = data["isCompleted"] as? Bool else {
                        return nil
                    }
                    let description = data["description"] as? String
                    let time = (data["time"] as? Timestamp)?.dateValue()
                    let endTime = (data["endTime"] as? Timestamp)?.dateValue()
                    var checklist: [ChecklistItem]? = nil
                    if let checklistArray = data["checklist"] as? [[String: Any]] {
                        checklist = checklistArray.compactMap { dict in
                            guard let id = dict["id"] as? String,
                                  let text = dict["text"] as? String,
                                  let isCompleted = dict["isCompleted"] as? Bool else { return nil }
                            return ChecklistItem(id: id, text: text, isCompleted: isCompleted)
                        }
                    }
                    let weekday = data["weekday"] as? Int ?? 1
                    let statusString = data["status"] as? String
                    let status = TaskStatus(rawValue: statusString ?? "normal") ?? .normal
                    return Task(
                        id: id,
                        title: title,
                        type: type,
                        userId: userId,
                        timestamp: timestamp,
                        weekday: weekday,
                        isCompleted: isCompleted,
                        description: description,
                        time: time,
                        endTime: endTime,
                        checklist: checklist,
                        status: status
                    )
                }
                
                completion(tasks)
            }
    }
    
    /// Удаляет задачу из Firestore
    func deleteTask(sessionCode: String, task: Task, completion: @escaping (Error?) -> Void) {
        db.collection("sessions").document(sessionCode)
            .collection("tasks").document(task.id)
            .delete { error in
                completion(error)
            }
    }
    
    /// Обновляет статус задачи по sessionCode и taskId
    func updateTaskStatus(sessionCode: String, taskId: String, status: TaskStatus) {
        let taskRef = db.collection("sessions").document(sessionCode).collection("tasks").document(taskId)
        taskRef.updateData(["status": status.rawValue]) { error in
            if let error = error {
                print("Ошибка при обновлении статуса задачи: \(error)")
            } else {
                print("Статус задачи успешно обновлён: \(taskId) -> \(status.rawValue)")
            }
        }
    }
}
