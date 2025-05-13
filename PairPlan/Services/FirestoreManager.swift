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
        return ref.order(by: "timestamp", descending: false)
            .addSnapshotListener { snap, _ in
                let tasks = snap?.documents.compactMap { doc -> Task? in
                    let d = doc.data()
                    guard let title      = d["title"] as? String,
                          let isCompleted = d["isCompleted"] as? Bool,
                          let ownerId     = d["ownerId"] as? String
                    else { return nil }
                    let ts = (d["timestamp"] as? Timestamp)?.dateValue()
                    return Task(
                        id: doc.documentID,
                        title: title,
                        timestamp: ts,
                        isCompleted: isCompleted,
                        ownerId: ownerId
                    )
                } ?? []
                onUpdate(tasks)
            }
    }

    /// Добавляет или обновляет задачу (upsert) без изменений
    func upsertTask(sessionCode: String,
                    task: Task,
                    completion: ((Error?) -> Void)? = nil) {
        let data: [String: Any] = [
            "title":       task.title,
            "timestamp":   task.timestamp.map { Timestamp(date: $0) } as Any,
            "isCompleted": task.isCompleted,
            "ownerId":     task.ownerId
        ]
        db.collection("sessions")
          .document(sessionCode)
          .collection("tasks")
          .document(task.id)
          .setData(data) { error in
            completion?(error)
        }
    }
}
