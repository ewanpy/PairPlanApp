// File: Services/FirestoreManager.swift
import Foundation
import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Session Management
    
    func createSession(code: String, mode: SessionMode, completion: @escaping (Error?) -> Void) {
        let sessionData: [String: Any] = [
            "code": code,
            "mode": mode.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "participants": []
        ]
        
        db.collection("sessions").document(code).setData(sessionData) { error in
            completion(error)
        }
    }
    
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
    
    // MARK: - Task Management
    
    func addTask(sessionCode: String, task: Task, completion: @escaping (Error?) -> Void) {
        var taskData: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "type": task.type.rawValue,
            "userId": task.userId,
            "timestamp": task.timestamp,
            "isCompleted": task.isCompleted
        ]
        if let description = task.description {
            taskData["description"] = description
        }
        if let time = task.time {
            taskData["time"] = time
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
                    var checklist: [ChecklistItem]? = nil
                    if let checklistArray = data["checklist"] as? [[String: Any]] {
                        checklist = checklistArray.compactMap { dict in
                            guard let id = dict["id"] as? String,
                                  let text = dict["text"] as? String,
                                  let isCompleted = dict["isCompleted"] as? Bool else { return nil }
                            return ChecklistItem(id: id, text: text, isCompleted: isCompleted)
                        }
                    }
                    return Task(
                        id: id,
                        title: title,
                        type: type,
                        userId: userId,
                        timestamp: timestamp,
                        isCompleted: isCompleted,
                        description: description,
                        time: time,
                        checklist: checklist
                    )
                }
                
                completion(tasks)
            }
    }
    
    func deleteTask(sessionCode: String, task: Task, completion: @escaping (Error?) -> Void) {
        db.collection("sessions").document(sessionCode)
            .collection("tasks").document(task.id)
            .delete { error in
                completion(error)
            }
    }
}
