// File: ViewModels/SessionViewModel.swift
import Foundation

class SessionViewModel: ObservableObject {
    @Published var sessionCode: String = ""
    @Published var joined:      Bool   = false
    @Published var errorMessage:String?
    @Published var mode:        SessionMode = .shared

    // храним идентификатор клиента в UserDefaults
    private let userIdKey = "PairPlan.currentUserId"
    private(set) var currentUserId: String

    init() {
        // либо читаем сохранённый, либо создаём новый
        if let saved = UserDefaults.standard.string(forKey: userIdKey) {
            currentUserId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            currentUserId = newId
        }
    }

    /// Создать новую сессию и сразу зарегистрироваться в ней
    func createSession(mode: SessionMode) {
        let code = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        self.mode = mode
        FirestoreManager.shared.createSession(code: code, mode: mode) { error in
            DispatchQueue.main.async {
                if let err = error {
                    self.errorMessage = err.localizedDescription
                    return
                }
                // Пробуем добавить себя как участника
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
                        }
                    }
                }
            }
        }
    }

    /// Попытка присоединиться к существующей сессии
    func joinSession(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "Поле не может быть пустым"
            return
        }
        // Сначала проверяем, что сессия есть
        FirestoreManager.shared.sessionExists(code: trimmed) { exists in
            DispatchQueue.main.async {
                guard exists else {
                    self.errorMessage = "Сессия не найдена"
                    return
                }
                // Подгружаем режим работы
                FirestoreManager.shared.loadSessionMode(code: trimmed) { loadedMode in
                    DispatchQueue.main.async {
                        guard let m = loadedMode else {
                            self.errorMessage = "Не удалось прочитать режим сессии"
                            return
                        }
                        self.mode = m
                        // Регистрируем участника
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
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
