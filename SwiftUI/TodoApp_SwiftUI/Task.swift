// MARK: - Task.swift
// Estrutura de dados que representa uma tarefa.
// Usada de forma idêntica nos dois projetos (UIKit e SwiftUI).

import Foundation

struct Task: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}
