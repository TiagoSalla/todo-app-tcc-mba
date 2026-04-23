// MARK: - TaskViewModel.swift
// ViewModel da arquitetura reativa.
//
// Erros controlados implementados aqui:
//   E1 — Modificação de @Published fora da main thread
//   E2 — AnyCancellable não armazenado: subscription cancelada ao sair do escopo
//   E3 — Force unwrap em estado inválido (crash determinístico)
//   E4 — Publisher que nunca emite

import Foundation
import Combine
import SwiftUI

protocol ReactiveTaskServiceProtocol {
    func fetchTasks() -> AnyPublisher<[Task], Never>
}

final class ReactiveTaskService: ReactiveTaskServiceProtocol {

    static var enableE4_NeverEmits: Bool = true

    func fetchTasks() -> AnyPublisher<[Task], Never> {

        // ⚠️ E4 — Publisher que nunca emite valor nem completion.
        // O subscriber fica preso, isLoading nunca volta para false,
        // ProgressView gira indefinidamente.
        if Self.enableE4_NeverEmits {
            print("[E4] fetchTasks chamado, mas publisher nunca emitirá.")
            return PassthroughSubject<[Task], Never>().eraseToAnyPublisher()
        }

        let novos = [
            Task(title: "Comprar pão"),
            Task(title: "Estudar Swift"),
            Task(title: "Revisar TCC")
        ]

        return Just(novos)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
}

@MainActor
final class TaskViewModel: ObservableObject {

    static var enableE1_BackgroundMutation: Bool = false
    static var enableE2_UnretainedCancellable: Bool = false
    static var enableE3_ForceUnwrap: Bool = false

    @Published private(set) var tasks: [Task] = []
    @Published private(set) var isLoading: Bool = false

    private let service: ReactiveTaskServiceProtocol

    // Armazenamento correto das subscriptions Combine.
    // ⚠️ E2: quando o bug está ativo, o .store(in:) é omitido
    // e este Set permanece vazio — a subscription é cancelada imediatamente.
    private var cancellables = Set<AnyCancellable>()

    init(service: ReactiveTaskServiceProtocol = ReactiveTaskService()) {
        self.service = service
    }

    func loadTasks() {
        isLoading = true

        // ⚠️ E2 — AnyCancellable não armazenado.
        //
        // O bug:
        // No Combine, cada chamada a .sink() retorna um AnyCancellable.
        // Esse objeto precisa ser armazenado — tipicamente em um Set<AnyCancellable>
        // via .store(in: &cancellables) — para manter a subscription ativa.
        //
        // Quando o AnyCancellable não é armazenado, o ARC o destrói imediatamente
        // ao sair do escopo da expressão. A subscription é cancelada antes de
        // o publisher emitir qualquer valor (o delay de 1 segundo ainda não passou).
        //
        // Resultado: isLoading fica true para sempre, a lista nunca é preenchida,
        // nenhum crash ocorre, nenhum log é gerado automaticamente.
        //
        // Este é um erro exclusivo do paradigma reativo — não tem equivalente
        // direto no UIKit. O compilador não emite nenhum aviso. O Crashlytics
        // não registra nada. A única pista é o comportamento silencioso da UI.
        //
        // Equivalente no UIKit (E2): EphemeralTaskService criado como variável
        // local, dealocado antes do completion handler completar.
        if Self.enableE2_UnretainedCancellable {
            // ⚠️ AnyCancellable descartado — subscription cancelada imediatamente
            _ = service.fetchTasks()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] novos in
                    // Este bloco NUNCA executa — subscription foi cancelada
                    guard let self = self else { return }
                    self.isLoading = false
                    self.tasks = novos
                }
            // Sem .store(in: &cancellables) — o AnyCancellable é destruído aqui
            print("[E2] Subscription criada sem armazenamento — será cancelada imediatamente.")
            return
        }

        service.fetchTasks()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] novos in
                guard let self = self else { return }
                self.isLoading = false
                self.tasks = novos
            }
            .store(in: &cancellables)
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(Task(title: trimmed))
    }

    func remove(at offsets: IndexSet) {
        // ⚠️ E1 — Mutação de @Published fora da main thread.
        if Self.enableE1_BackgroundMutation {
            DispatchQueue.global().async { [weak self] in
                self?.tasks.remove(atOffsets: offsets)
            }
        } else {
            tasks.remove(atOffsets: offsets)
        }
    }

    func toggle(_ task: Task) {
        // ⚠️ E3 — Force unwrap em estado inválido (crash determinístico).
        if Self.enableE3_ForceUnwrap {
            let targetID = task.id

            _Concurrency.Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await _Concurrency.Task.sleep(nanoseconds: 1_500_000_000)
                self.tasks.removeAll { $0.id == targetID }
            }

            _Concurrency.Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000)
                let index = self.tasks.firstIndex(where: { $0.id == targetID })!
                self.tasks[index].isCompleted.toggle()
            }
        } else {
            guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
            tasks[index].isCompleted.toggle()
        }
    }
}
