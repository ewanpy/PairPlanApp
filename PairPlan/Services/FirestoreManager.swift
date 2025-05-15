// File: Services/FirestoreManager.swift
import Foundation
import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()

    /// Создает сессию с выбранным режимом (shared/individual)
    func createSession(code: String,
                       mode: SessionMode,
                       completion: @escaping (Error?) -> Void) {
        let sessionRef = db.collection("sessions").document(code)
        let metaRef    = sessionRef.collection("meta").document("settings")
        let sessionData: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp()
        ]
        let settingsData: [String: Any] = [
            "mode":      mode.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        let batch = db.batch()
        batch.setData(sessionData,   forDocument: sessionRef)
        batch.setData(settingsData,  forDocument: metaRef)
        batch.commit { error in
            completion(error)
        }
    }

    /// Проверяет, существует ли сессия
    func sessionExists(code: String,
                       completion: @escaping (Bool) -> Void) {
        db.collection("sessions").document(code)
          .getDocument { snap, _ in
            completion(snap?.exists == true)
        }
    }

    /// Загружает режим работы сессии (shared/individual)
    func loadSessionMode(code: String,
                         completion: @escaping (SessionMode?) -> Void) {
        let metaRef = db.collection("sessions")
                         .document(code)
                         .collection("meta")
                         .document("settings")
        
        metaRef.getDocument { snap, _ in
            guard let data = snap?.data(),
                  let raw  = data["mode"] as? String,
                  let mode = SessionMode(rawValue: raw)
            else {
                completion(nil)
                return
            }
            completion(mode)
        }
    }

    /// Добавляет участника в сессию.
    /// Если режим individual и участников уже 2 — возвращает success = false.
    func addParticipant(sessionCode: String,
                        userId: String,
                        isIndividual: Bool,
                        completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        let partRef = db.collection("sessions")
                         .document(sessionCode)
                         .collection("participants")
        partRef.getDocuments { snapshot, error in
            if let error = error {
                return completion(false, error)
            }
            let count = snapshot?.documents.count ?? 0
            if isIndividual && count >= 2 {
                return completion(false, nil)
            }
            partRef.document(userId).setData([
                "joinedAt": FieldValue.serverTimestamp()
            ]) { err in
                completion(err == nil, err)
            }
        }
    }

    /// Наблюдение за задачами (ручной маппинг ownerId)
    func observeTasks(sessionCode: String,
                      onUpdate: @escaping ([Task]) -> Void) -> ListenerRegistration {
        let ref = db.collection("sessions")
                    .document(sessionCode)
                    .collection("tasks")
        
        return ref.addSnapshotListener { snap, _ in
            let tasks = snap?.documents.compactMap { doc -> Task? in
                let d = doc.data()
                guard let title      = d["title"] as? String,
                      let isCompleted = d["isCompleted"] as? Bool,
                      let ownerId     = d["ownerId"] as? String,
                      let typeRaw     = d["type"] as? String,
                      let type        = TaskType(rawValue: typeRaw)
                else { return nil }
                let ts = (d["timestamp"] as? Timestamp)?.dateValue()
                let color = d["color"] as? String
                let description = d["description"] as? String
                let attachments = d["attachments"] as? [String]
                let repeatRule = d["repeatRule"] as? String
                var checklist: [ChecklistItem]? = nil
                if let checklistArr = d["checklist"] as? [[String: Any]] {
                    checklist = checklistArr.compactMap { itemDict in
                        guard let text = itemDict["text"] as? String else { return nil }
                        let isCompleted = itemDict["isCompleted"] as? Bool ?? false
                        let id = itemDict["id"] as? String ?? UUID().uuidString
                        return ChecklistItem(id: id, text: text, isCompleted: isCompleted)
                    }
                }
                return Task(
                    id: doc.documentID,
                    title: title,
                    timestamp: ts,
                    isCompleted: isCompleted,
                    ownerId: ownerId,
                    type: type,
                    color: color,
                    description: description,
                    attachments: attachments,
                    repeatRule: repeatRule,
                    checklist: checklist
                )
            } ?? []
            onUpdate(tasks)
        }
    }

    /// Добавляет или обновляет задачу (upsert) с поддержкой новых полей
    func upsertTask(sessionCode: String,
                    task: Task,
                    completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title":       task.title,
            "timestamp":   task.timestamp.map { Timestamp(date: $0) } as Any,
            "isCompleted": task.isCompleted,
            "ownerId":     task.ownerId,
            "type":        task.type.rawValue
        ]
        if let color = task.color { data["color"] = color }
        if let description = task.description { data["description"] = description }
        if let attachments = task.attachments { data["attachments"] = attachments }
        if let repeatRule = task.repeatRule { data["repeatRule"] = repeatRule }
        if let checklist = task.checklist {
            data["checklist"] = checklist.map { [
                "id": $0.id,
                "text": $0.text,
                "isCompleted": $0.isCompleted
            ] }
        }
        db.collection("sessions")
          .document(sessionCode)
          .collection("tasks")
          .document(task.id)
          .setData(data) { error in
            completion?(error)
        }
    }

    /// Удаляет задачу
    func deleteTask(sessionCode: String,
                   taskId: String,
                   completion: ((Error?) -> Void)? = nil) {
        db.collection("sessions")
          .document(sessionCode)
          .collection("tasks")
          .document(taskId)
          .delete { error in
            completion?(error)
        }
    }

    /// Удаляет участника из сессии и удаляет сессию, если участников не осталось
    func removeParticipant(sessionCode: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let partRef = db.collection("sessions")
            .document(sessionCode)
            .collection("participants")
            .document(userId)
        partRef.delete { error in
            if let error = error {
                completion?(error)
                return
            }
            // After removal, check if any participants remain
            self.checkAndDeleteSessionIfEmpty(sessionCode: sessionCode, completion: completion)
        }
    }

    private func checkAndDeleteSessionIfEmpty(sessionCode: String, completion: ((Error?) -> Void)? = nil) {
        let partRef = db.collection("sessions")
            .document(sessionCode)
            .collection("participants")
        partRef.getDocuments { snapshot, error in
            if let error = error {
                completion?(error)
                return
            }
            // Do NOT delete the session if count == 0
            completion?(nil)
        }
    }

    func deleteSession(sessionCode: String, completion: ((Error?) -> Void)? = nil) {
        let sessionRef = db.collection("sessions").document(sessionCode)
        // Delete all tasks
        sessionRef.collection("tasks").getDocuments { (snapshot, error) in
            let batch = self.db.batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
            // Delete all participants
            sessionRef.collection("participants").getDocuments { (psnapshot, _) in
                psnapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                // Delete meta/settings
                sessionRef.collection("meta").getDocuments { (msnapshot, _) in
                    msnapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    // Delete the session document itself
                    batch.deleteDocument(sessionRef)
                    batch.commit { error in
                        completion?(error)
                    }
                }
            }
        }
    }
}
