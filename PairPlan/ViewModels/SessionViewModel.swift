// File: ViewModels/SessionViewModel.swift
import Foundation

class SessionViewModel: ObservableObject {
    @Published var sessionCode: String = ""
    @Published var joined:      Bool   = false
    @Published var errorMessage:String?
    @Published var mode:        SessionMode = .shared

    // MARK: — Identity
    private let userIdKey = "PairPlan.currentUserId"
    private(set) var currentUserId: String

    // MARK: — Recent Sessions
    private let recentSessionsKey = "PairPlan.recentSessions"
    @Published var recentSessions: [String] = []

    @Published var mySessions: [Session] = []

    init() {
        // При первом запуске сохраняем UUID, затем читаем его при каждом старте
        if let saved = UserDefaults.standard.string(forKey: userIdKey) {
            currentUserId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            currentUserId = newId
        }
        // Load recent sessions
        if let saved = UserDefaults.standard.array(forKey: recentSessionsKey) as? [String] {
            recentSessions = saved
        }
        loadMySessions()
    }

    // MARK: — Session lifecycle

    /// Создать новую сессию и зарегистрировать в ней этого пользователя
    func createSession(mode: SessionMode) {
        let code = String((0..<6).map { _ in
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!
        })
        self.mode = mode
        FirestoreManager.shared.createSession(code: code, mode: mode, ownerId: currentUserId) { error in
            DispatchQueue.main.async {
                if let err = error {
                    self.errorMessage = err.localizedDescription
                    return
                }
                FirestoreManager.shared.addParticipant(
                    sessionCode: code,
                    userId: self.currentUserId,
                    isIndividual: mode == .individual
                ) { success, err in
                    DispatchQueue.main.async {
                        if let err = err {
                            self.errorMessage = err.localizedDescription
                        } else if !success {
                            self.errorMessage = "Нельзя создать сессию: достигнут лимит участников."
                        } else {
                            self.sessionCode = code
                            self.joined = true
                            self.addRecentSession(code)
                            self.loadMySessions()
                        }
                    }
                }
            }
        }
    }

    /// Присоединиться к уже существующей сессии по коду
    func joinSession(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "Поле не может быть пустым"
            return
        }
        // 1) Проверяем, что сессия существует
        FirestoreManager.shared.sessionExists(code: trimmed) { exists in
            DispatchQueue.main.async {
                guard exists else {
                    self.errorMessage = "Сессия не найдена"
                    return
                }
                // 2) Загружаем её режим работы
                FirestoreManager.shared.loadSessionMode(code: trimmed) { loadedMode in
                    DispatchQueue.main.async {
                        guard let m = loadedMode else {
                            self.errorMessage = "Не удалось прочитать режим сессии"
                            return
                        }
                        self.mode = m
                        // 3) Пытаемся добавить себя в participants
                        FirestoreManager.shared.addParticipant(
                            sessionCode: trimmed,
                            userId: self.currentUserId,
                            isIndividual: m == .individual
                        ) { success, err in
                            DispatchQueue.main.async {
                                if let err = err {
                                    self.errorMessage = err.localizedDescription
                                } else if !success {
                                    self.errorMessage = "Невозможно присоединиться: сессия заполнена."
                                } else {
                                    self.sessionCode = trimmed
                                    self.joined = true
                                    self.addRecentSession(trimmed)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Выход из текущей сессии — удаляет участника из Firestore и возвращает на экран входа
    func leaveSession() {
        let code = sessionCode
        let userId = currentUserId
        FirestoreManager.shared.removeParticipant(sessionCode: code, userId: userId) { [weak self] error in
            DispatchQueue.main.async {
                // Optionally handle error
                self?.sessionCode  = ""
                self?.joined       = false
                self?.mode         = .shared
                self?.errorMessage = nil
            }
        }
    }

    // MARK: — Recent Sessions Logic
    func addRecentSession(_ code: String) {
        var set = Set(recentSessions)
        set.insert(code)
        recentSessions = Array(set)
        UserDefaults.standard.set(recentSessions, forKey: recentSessionsKey)
    }

    func removeRecentSession(_ code: String) {
        recentSessions.removeAll { $0 == code }
        UserDefaults.standard.set(recentSessions, forKey: recentSessionsKey)
    }

    func clearRecentSessions() {
        recentSessions = []
        UserDefaults.standard.removeObject(forKey: recentSessionsKey)
    }

    func loadMySessions() {
        FirestoreManager.shared.loadSessions(for: currentUserId) { sessions in
            DispatchQueue.main.async {
                self.mySessions = sessions
            }
        }
    }

    /// Удаляет сессию и обновляет список сессий
    func deleteSession(_ session: Session) {
        FirestoreManager.shared.deleteSession(code: session.code) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    // Удаляем сессию из локального списка
                    self?.mySessions.removeAll { $0.code == session.code }
                    // Удаляем из недавних сессий
                    self?.removeRecentSession(session.code)
                }
            }
        }
    }
}

struct Session: Identifiable {
    var id: String { code }
    let code: String
    let mode: SessionMode
    let ownerId: String
}
