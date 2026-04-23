// MARK: - TaskListView.swift
// Tela principal do app reativo.

import SwiftUI

struct TaskListView: View {

    @StateObject private var viewModel = TaskViewModel()
    @State private var showingAddSheet = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(viewModel.tasks) { task in
                        TaskRow(task: task) {
                            viewModel.toggle(task)
                        }
                    }
                    .onDelete(perform: viewModel.remove)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    // Para reproduzir E2: dispare pull-to-refresh duas vezes em sequência.
                    viewModel.loadTasks()
                }

                if viewModel.isLoading {
                    ProgressView("Carregando...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Tarefas (SwiftUI)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTaskSheet(title: $newTitle) { title in
                    viewModel.add(title: title)
                    newTitle = ""
                    showingAddSheet = false
                }
            }
            .onAppear {
                viewModel.loadTasks()
            }
        }
    }
}

struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                Text(task.isCompleted ? "✓ Concluída" : "Pendente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
        }
    }
}

struct AddTaskSheet: View {
    @Binding var title: String
    let onConfirm: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Nova tarefa") {
                    TextField("Título", text: $title)
                }
            }
            .navigationTitle("Adicionar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") { onConfirm(title) }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    TaskListView()
}
