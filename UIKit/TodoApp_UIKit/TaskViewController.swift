// MARK: - TaskViewController.swift
// View controller principal do app UIKit.
//
// Erros controlados implementados aqui:
//   E1 — Inconsistência entre model e UITableView
//   E2 — Serviço efêmero dealocado antes do callback completar
//   E3 — Force unwrap em estado inválido (crash determinístico)

import UIKit
import FirebaseCrashlytics

final class TaskViewController: UIViewController {

    // ⚠️ Flags dos cenários implementados neste arquivo.
    static var enableE1_StateInconsistency: Bool = false
    static var enableE2_EphemeralService: Bool = false
    static var enableE3_ForceUnwrap: Bool = false

    private let service: TaskServiceProtocol
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()

    init(service: TaskServiceProtocol = TaskService()) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não suportado") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tarefas (UIKit)"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped)
        )

        configureTableView()
        configureActivityIndicator()
        loadTasks()
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadTasks() {
        activityIndicator.startAnimating()

        // ⚠️ E2 — Serviço efêmero: instância criada como variável local.
        //
        // Quando enableE2_EphemeralService = true, em vez de usar self.service
        // (propriedade armazenada com referência forte), criamos um EphemeralTaskService
        // como variável local. Ao sair do escopo de loadTasks(), o ARC destrói
        // o objeto — antes que o callback de 1 segundo complete.
        //
        // O completion handler nunca é chamado. O activityIndicator para de girar
        // apenas quando o usuário fechar o app. Nenhum crash, nenhum log automático.
        //
        // Equivalente no Combine: .sink { } sem .store(in: &cancellables) —
        // a subscription é cancelada imediatamente ao sair do escopo.
        if Self.enableE2_EphemeralService {
            let ephemeral = EphemeralTaskService()
            // ephemeral será dealocado após esta função retornar
            ephemeral.fetchTasks { [weak self] tasks in
                // Este bloco nunca executa — ephemeral foi dealocado
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                self.tableView.reloadData()
            }
            // ephemeral dealocado aqui — sem referência forte mantida
            return
        }

        service.fetchTasks { [weak self] _ in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
            self.tableView.reloadData()
        }
    }

    @objc private func pullToRefresh() { loadTasks() }

    @objc private func addTapped() {
        let alert = UIAlertController(title: "Nova tarefa", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Título" }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Adicionar", style: .default) { [weak self] _ in
            guard let title = alert.textFields?.first?.text, !title.isEmpty else { return }
            self?.service.add(Task(title: title))
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate
extension TaskViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        service.tasks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let task = service.tasks[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = task.title
        config.secondaryText = task.isCompleted ? "✓ Concluída" : "Pendente"
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // ⚠️ E3 — Force unwrap em estado inválido (crash determinístico).
        if Self.enableE3_ForceUnwrap {
            guard !service.tasks.isEmpty else { return }
            let selectedTask = service.tasks[indexPath.row]

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if let idx = self.service.tasks.firstIndex(where: { $0.id == selectedTask.id }) {
                    self.service.remove(at: idx)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                let index = self.service.tasks.firstIndex(where: { $0.id == selectedTask.id })!
                self.service.toggle(at: index)
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        } else {
            guard let task = service.tasks[safe: indexPath.row],
                  let index = service.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            service.toggle(at: index)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }

        service.remove(at: indexPath.row)

        // ⚠️ E1 — Inconsistência entre model e UITableView.
        if Self.enableE1_StateInconsistency {
            // Força um reload imediato — UITableView detecta a discrepância
            // entre numberOfRows anterior e atual e crasha.
            tableView.beginUpdates()
            // deleteRows ESQUECIDO de propósito
            tableView.endUpdates()
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
