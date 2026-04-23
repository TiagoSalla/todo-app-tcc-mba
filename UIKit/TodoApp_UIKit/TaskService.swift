// MARK: - TaskService.swift
// Camada de dados do app UIKit. Usa completion handlers (callbacks).
//
// Erros controlados implementados aqui:
//   E2 — Serviço criado como variável local, dealocado antes do callback completar
//   E4 — Completion handler nunca chamado

import Foundation

protocol TaskServiceProtocol {
    func fetchTasks(completion: @escaping ([Task]) -> Void)
    func add(_ task: Task)
    func remove(at index: Int)
    func toggle(at index: Int)
    var tasks: [Task] { get }
}

final class TaskService: TaskServiceProtocol {

    // ⚠️ Flags de controle dos cenários de erro.
    static var enableE4_NeverCompletes: Bool = true

    private(set) var tasks: [Task] = []

    func add(_ task: Task) {
        tasks.append(task)
    }

    func remove(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks.remove(at: index)
    }

    func toggle(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks[index].isCompleted.toggle()
    }

    func fetchTasks(completion: @escaping ([Task]) -> Void) {

        // ⚠️ E4 — Travamento sem crash.
        // Quando ativo, retorna sem nunca chamar completion.
        // Resultado: o UIActivityIndicatorView gira indefinidamente.
        if Self.enableE4_NeverCompletes {
            print("[E4] fetchTasks chamado, mas completion nunca será invocado.")
            return
        }

        let novos = [
            Task(title: "Comprar pão"),
            Task(title: "Estudar Swift"),
            Task(title: "Revisar TCC")
        ]

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else {
                // ⚠️ E2: self foi dealocado — callback nunca executa.
                // O ViewController nunca recebe os dados e permanece no estado de loading.
                // Nenhum crash, nenhum log automático — falha completamente silenciosa.
                print("[E2] TaskService foi dealocado antes do callback completar.")
                return
            }
            self.tasks = novos
            DispatchQueue.main.async { completion(self.tasks) }
        }
    }
}

// MARK: - TaskService efêmero — usado para simular o E2
//
// ⚠️ E2 — Gerenciamento incorreto de ciclo de vida do serviço (UIKit).
//
// O bug:
// Em vez de usar o TaskService armazenado como propriedade do ViewController,
// criamos uma instância local dentro do método loadTasks().
// Como o ARC não mantém referência forte ao objeto, ele é dealocado
// imediatamente ao sair do escopo da função — antes que o callback assíncrono
// de 1 segundo complete.
//
// Resultado: o completion handler nunca é chamado, o loading indicator
// gira indefinidamente e nenhum log ou alerta é gerado.
//
// Equivalente reativo no SwiftUI/Combine: AnyCancellable não armazenado
// em cancellables — a subscription é cancelada imediatamente ao sair do escopo.
//
// Em produção, esse erro ocorre tipicamente quando um desenvolvedor cria um
// serviço de rede dentro de uma closure ou método sem preservar a referência,
// ou quando usa [unowned self] em objetos com ciclo de vida curto.
final class EphemeralTaskService {
    func fetchTasks(completion: @escaping ([Task]) -> Void) {
        let novos = [
            Task(title: "Comprar pão"),
            Task(title: "Estudar Swift"),
            Task(title: "Revisar TCC")
        ]
        // Simula latência de rede — o objeto será dealocado antes disso completar
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else {
                print("[E2] EphemeralTaskService dealocado — completion nunca chamado.")
                return
            }
            DispatchQueue.main.async { completion(novos) }
        }
    }
}
