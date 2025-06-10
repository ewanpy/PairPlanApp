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
    @State private var showLogoutAlert = false
    @State private var showAddTask = false
    @State private var showAccountMenu = false
    var onLogout: (() -> Void)? = nil
    @Binding var appColorScheme: ColorScheme?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.joined {
                    // Экран задач с кнопкой "Назад" в навигационной панели
                    TaskListView(
                        sessionCode: viewModel.sessionCode,
                        mode: viewModel.mode,
                        showAddTask: $showAddTask
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
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showAddTask = true }) {
                                Image(systemName: "plus")
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
                            if !viewModel.mySessions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.accentColor)
                                            .font(.title2)
                                        Text("Мои сессии")
                                            .font(.headline)
                                        Spacer()
                                        Button(action: { viewModel.loadMySessions() }) {
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundColor(.accentColor)
                                        }
                                        .accessibilityLabel("Обновить список сессий")
                                    }
                                    ForEach(viewModel.mySessions) { session in
                                        HStack(spacing: 12) {
                                            Image(systemName: "rectangle.stack.person.crop")
                                                .foregroundColor(.accentColor)
                                                .font(.title3)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Сессия")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                HStack(spacing: 8) {
                                                    Text(session.code)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Text(session.mode == .shared ? "Общий" : "Индивидуальный")
                                                        .font(.caption)
                                                        .foregroundColor(session.mode == .shared ? .blue : .orange)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill((session.mode == .shared ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12)))
                                                        )
                                                }
                                            }
                                            Spacer()
                                            Button(action: { viewModel.deleteSession(session) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .accessibilityLabel("Удалить сессию")
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
                                                recentJoinButtonPressed = session.code
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    recentJoinButtonPressed = nil
                                                    viewModel.joinSession(code: session.code)
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { showAccountMenu = true }) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                            }
                            .accessibilityLabel("Аккаунт и настройки")
                        }
                    }
                    .sheet(isPresented: $showAccountMenu) {
                        AccountMenuView(onLogout: onLogout, appColorScheme: $appColorScheme)
                    }
                }
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("Выйти из аккаунта?"),
                    message: Text("Вы уверены, что хотите выйти?"),
                    primaryButton: .destructive(Text("Выйти")) {
                        onLogout?()
                    },
                    secondaryButton: .cancel(Text("Отмена"))
                )
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

struct AccountMenuView: View {
    var onLogout: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showProfile = false
    @State private var showSettings = false
    @Binding var appColorScheme: ColorScheme?
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Аккаунт")) {
                    Button(action: { showProfile = true }) {
                        Label("Профиль", systemImage: "person")
                    }
                }
                Section(header: Text("Приложение")) {
                    Button(action: { showSettings = true }) {
                        Label("Настройки", systemImage: "gear")
                    }
                    Button(action: { /* TODO: Справка */ }) {
                        Label("Справка", systemImage: "questionmark.circle")
                    }
                    Button(action: { /* TODO: О приложении */ }) {
                        Label("О приложении", systemImage: "info.circle")
                    }
                }
                Section {
                    Button(role: .destructive, action: {
                        dismiss()
                        onLogout?()
                    }) {
                        Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Меню")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .background(
                NavigationLink(destination: ProfileView(), isActive: $showProfile) { EmptyView() }.hidden()
            )
            .background(
                NavigationLink(destination: SettingsView(appColorScheme: $appColorScheme), isActive: $showSettings) { EmptyView() }.hidden()
            )
        }
    }
}

// Экран профиля пользователя
struct ProfileView: View {
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.top, 32)
            if isLoading {
                ProgressView()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                Text("Username: \(username)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Email: \(email)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Button("Редактировать профиль") {
                // TODO: Реализовать редактирование
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
            .foregroundColor(.accentColor)
            .padding(.top, 16)
            Spacer()
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
        .onAppear {
            loadProfile()
        }
    }
    private func loadProfile() {
        guard let userId = UserDefaults.standard.string(forKey: "PairPlan.currentUserId") else {
            errorMessage = "Не удалось получить userId"
            isLoading = false
            return
        }
        FirestoreManager.shared.getUsername(userId: userId) { name in
            DispatchQueue.main.async {
                if let name = name {
                    self.username = name
                } else {
                    self.username = "-"
                }
            }
        }
        FirestoreManager.shared.getUserEmail(userId: userId) { mail in
            DispatchQueue.main.async {
                if let mail = mail {
                    self.email = mail
                } else {
                    self.email = "-"
                }
                self.isLoading = false
            }
        }
    }
}

// Экран настроек приложения
struct SettingsView: View {
    @Binding var appColorScheme: ColorScheme?
    @State private var selectedTheme: Int = 0 // 0 - system, 1 - light, 2 - dark
    var body: some View {
        Form {
            Section(header: Text("Внешний вид")) {
                Picker("Тема", selection: $selectedTheme) {
                    Text("Системная").tag(0)
                    Text("Светлая").tag(1)
                    Text("Тёмная").tag(2)
                }
                .onChange(of: selectedTheme) { newValue in
                    switch newValue {
                    case 1:
                        appColorScheme = .light
                        UserDefaults.standard.set("light", forKey: "PairPlan.AppColorScheme")
                    case 2:
                        appColorScheme = .dark
                        UserDefaults.standard.set("dark", forKey: "PairPlan.AppColorScheme")
                    default:
                        appColorScheme = nil
                        UserDefaults.standard.set("system", forKey: "PairPlan.AppColorScheme")
                    }
                }
            }
            Section(header: Text("Уведомления")) {
                Toggle("Разрешить уведомления", isOn: .constant(true))
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Установить selectedTheme по текущей теме
            if let saved = UserDefaults.standard.string(forKey: "PairPlan.AppColorScheme") {
                switch saved {
                case "light": selectedTheme = 1
                case "dark": selectedTheme = 2
                default: selectedTheme = 0
                }
            } else {
                selectedTheme = 0
            }
        }
    }
}
