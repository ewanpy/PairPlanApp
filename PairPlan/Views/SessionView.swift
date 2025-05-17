import SwiftUI

struct SessionView: View {
    @EnvironmentObject var viewModel: SessionViewModel
    @State private var selectedMode: SessionMode = .shared
    @State private var selectedTaskTypes: Set<TaskType> = Set(TaskType.allCases)
    @State private var showTaskTypeSelection = false
    @State private var showModeSelection = false
    @State private var joinButtonPressed = false
    @State private var createButtonPressed = false
    @State private var modeSelectionMade = false
    @State private var recentJoinButtonPressed: String? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.joined {
                    // Экран задач с кнопкой "Назад" в навигационной панели
                    TaskListView(
                        sessionCode: viewModel.sessionCode,
                        mode: viewModel.mode
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { viewModel.leaveSession() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Назад")
                                }
                            }
                        }
                    }
                } else {
                    // Экран создания/присоединения к сессии
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundColor(.accentColor)
                                Text("Совместное планирование")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            .padding(.top, 40)
                            
                            // Recent Sessions
                            if !viewModel.recentSessions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.accentColor)
                                            .font(.title2)
                                        Text("Недавние сессии")
                                            .font(.headline)
                                        Spacer()
                                        Button(action: { viewModel.clearRecentSessions() }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .accessibilityLabel("Очистить недавние сессии")
                                    }
                                    ForEach(viewModel.recentSessions, id: \.self) { code in
                                        HStack(spacing: 12) {
                                            Image(systemName: "rectangle.stack.person.crop")
                                                .foregroundColor(.accentColor)
                                                .font(.title3)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Сессия")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(code)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Button(action: { viewModel.removeRecentSession(code) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(.systemBackground))
                                                .shadow(color: Color(.black).opacity(0.08), radius: 4, x: 0, y: 2)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.5)) {
                                                recentJoinButtonPressed = code
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    recentJoinButtonPressed = nil
                                                    viewModel.joinSession(code: code)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Session Code Input
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.accentColor)
                                    TextField("Код сессии", text: $viewModel.sessionCode)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(.systemGray6))
                                                .shadow(color: Color(.black).opacity(0.08), radius: 2, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                        )
                                        .frame(maxWidth: 220)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(
                                                #selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil
                                            )
                                        }
                                }
                                
                                HStack(spacing: 20) {
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.5)) {
                                            createButtonPressed.toggle()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                createButtonPressed.toggle()
                                                showModeSelection = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.headline)
                                            Text("Создать")
                                                .font(.headline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                                .clipped()
                                        }
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.accentColor)
                                        )
                                    }
                                    .foregroundColor(.white)
                                    .scaleEffect(createButtonPressed ? 0.95 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: createButtonPressed)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.5)) {
                                            joinButtonPressed.toggle()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                joinButtonPressed.toggle()
                                                viewModel.joinSession(code: viewModel.sessionCode)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "person.badge.plus")
                                                .font(.headline)
                                            Text("Вступить")
                                                .font(.headline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                                .clipped()
                                        }
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.accentColor)
                                        )
                                    }
                                    .foregroundColor(.white)
                                    .scaleEffect(joinButtonPressed ? 0.95 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: joinButtonPressed)
                                }
                                .padding(.horizontal)
                            }
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .navigationTitle("PairPlan")
                }
            }
        }
        .sheet(isPresented: $showModeSelection, onDismiss: {
            modeSelectionMade = false
            selectedMode = .shared
        }) {
            NavigationView {
                VStack(spacing: 24) {
                    Text("Выберите режим работы")
                        .font(.title3)
                        .padding(.bottom, 8)
                    HStack(spacing: 16) {
                        ForEach([SessionMode.shared, .individual], id: \.self) { mode in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedMode = mode
                                    modeSelectionMade = true
                                }
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 36))
                                    Text(mode.description)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, minHeight: 90)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(modeSelectionMade && selectedMode == mode ? Color.accentColor : Color(.systemGray5))
                                        .animation(.easeInOut(duration: 0.2), value: selectedMode)
                                )
                                .foregroundColor(modeSelectionMade && selectedMode == mode ? .white : .primary)
                                .scaleEffect(modeSelectionMade && selectedMode == mode ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMode)
                            }
                        }
                    }
                    .padding(.horizontal)
                    if modeSelectionMade && (selectedMode == .shared || selectedMode == .individual) {
                        Button(action: {
                            viewModel.createSession(mode: selectedMode)
                            showModeSelection = false
                        }) {
                            Text("Подтвердить")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Spacer()
                }
                .navigationTitle("Режим работы")
                .navigationBarItems(trailing: Button("Отмена") {
                    showModeSelection = false
                })
            }
        }
        .sheet(isPresented: $showTaskTypeSelection) {
            NavigationView {
                List(TaskType.allCases, id: \.self) { type in
                    Button {
                        if selectedTaskTypes.contains(type) {
                            selectedTaskTypes.remove(type)
                        } else {
                            selectedTaskTypes.insert(type)
                        }
                    } label: {
                        HStack {
                            Label(type.rawValue, systemImage: type.icon)
                            Spacer()
                            if selectedTaskTypes.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                .navigationTitle("Типы задач")
                .navigationBarItems(trailing: Button("Готово") {
                    showTaskTypeSelection = false
                })
            }
        }
    }
}
