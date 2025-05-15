import SwiftUI
import PhotosUI
import Foundation

struct TaskListView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var showAdd = false
    @State private var editingTask: Task? = nil
    @State private var checklistTask: Task? = nil // For checklist sheet
    @EnvironmentObject var sessionVM: SessionViewModel

    let sessionCode: String
    let mode: SessionMode

    init(sessionCode: String, mode: SessionMode) {
        self.sessionCode = sessionCode
        self.mode = mode
        _viewModel = StateObject(
            wrappedValue: TaskListViewModel(
                sessionCode: sessionCode,
                mode: mode
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            if mode == .shared {
                sharedListView
            } else {
                groupedScrollView
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTaskView { title, date, type, colorHex, description, attachments, repeatRule, checklist in
                viewModel.addTask(
                    title: title,
                    at: date,
                    type: type,
                    colorHex: colorHex,
                    description: description,
                    attachments: attachments,
                    repeatRule: repeatRule,
                    checklist: checklist
                )
                showAdd = false
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task) { updatedTask in
                viewModel.updateTask(updatedTask)
                editingTask = nil
            }
        }
        .sheet(item: $checklistTask) { task in
            ChecklistSheet(task: task) { updatedTask in
                viewModel.updateTask(updatedTask)
                checklistTask = nil
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Сессия: \(sessionCode)")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button { showAdd.toggle() } label: {
                Label("Добавить", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }

    private var sharedListView: some View {
        List(viewModel.tasks) { task in
            TaskRow(
                task: task,
                mode: mode,
                currentUserId: viewModel.currentUserId,
                onEdit: { editingTask = task },
                onDelete: { viewModel.deleteTask(task) },
                action: { viewModel.toggleCompletion(of: task) },
                onChecklist: { checklistTask = task }
            )
        }
        .listStyle(.insetGrouped)
    }

    private var groupedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedTasks.keys.sorted(by: >), id: \.self) { date in
                    VStack(spacing: 8) {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                        taskBubbleList(for: date)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var groupedTasks: [Date: [Task]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.tasks) { task in
            calendar.startOfDay(for: task.timestamp ?? Date())
        }
        // Sort each group by time (timestamp) in ascending order
        var sortedGrouped: [Date: [Task]] = [:]
        for (date, tasks) in grouped {
            sortedGrouped[date] = tasks.sorted {
                let t1 = $0.timestamp ?? Date.distantPast
                let t2 = $1.timestamp ?? Date.distantPast
                return t1 < t2
            }
        }
        return sortedGrouped
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func taskBubbleList(for date: Date) -> some View {
        ForEach(groupedTasks[date] ?? []) { task in
            TaskBubble(
                task: task,
                isCurrentUser: task.ownerId == viewModel.currentUserId,
                onEdit: { editingTask = task },
                onDelete: { viewModel.deleteTask(task) },
                action: { viewModel.toggleCompletion(of: task) },
                onChecklist: { checklistTask = task }
            )
        }
    }
}

// Helper to convert hex string to Color
extension Color {
    init?(hex: String?) {
        guard let hex = hex else { self = .accentColor; return }
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { self = .accentColor; return }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
