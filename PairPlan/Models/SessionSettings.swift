// File: Models/SessionSettings.swift
import Foundation

enum TaskType: String, CaseIterable {
    case work = "Работа"
    case study = "Учёба"
    case personal = "Личное"
    case other = "Другое"
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .personal: return "person.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum SessionMode: String {
    case shared
    case individual
    
    var description: String {
        switch self {
        case .shared: return "Общие задачи"
        case .individual: return "Индивидуальные задачи"
        }
    }
    
    var icon: String {
        switch self {
        case .shared: return "person.2.fill"
        case .individual: return "person.fill"
        }
    }
}
