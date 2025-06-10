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
    @State private var username: String = ""
    @State private var isLoadingUsername = false
    @State private var showJoinByCode = false
    @State private var joinCode: String = ""
    @State private var showSavedSessions = false
    
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
                            // Приветствие и аватар
                            HStack(alignment: .center, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(.accentColor)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    if isLoadingUsername {
                                        ProgressView().frame(height: 20)
                                    } else {
                                        Text("Добро пожаловать,\n\(username.isEmpty ? "пользователь" : username)!")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.top, 32)
                            // Блок быстрых действий
                            HStack(spacing: 16) {
                                QuickActionButton(
                                    title: "Создать\nсессию",
                                    systemImage: "plus.circle",
                                    foregroundColor: Color.blue,
                                    backgroundColor: Color.blue.opacity(0.08),
                                    action: { showModeSelection = true }
                                )
                                QuickActionButton(
                                    title: "Войти\nпо коду",
                                    systemImage: "key.fill",
                                    foregroundColor: Color.blue,
                                    backgroundColor: Color.blue.opacity(0.08),
                                    action: { showJoinByCode = true }
                                )
                                QuickActionButton(
                                    title: "Мои\nсессии",
                                    systemImage: "rectangle.stack.person.crop",
                                    foregroundColor: Color.orange,
                                    backgroundColor: Color.orange.opacity(0.12),
                                    action: {
                                        showSavedSessions = true
                                        viewModel.loadMySessions()
                                    }
                                )
                            }
                            // Блок последних сессий
                            RecentSessionsBlock(
                                recentCodes: viewModel.recentSessions,
                                allSessions: viewModel.mySessions,
                                onJoin: { code in viewModel.joinSession(code: code) }
                            )
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
                    .onAppear {
                        loadUsername()
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
        .sheet(isPresented: $showJoinByCode) {
            JoinByCodeSheet(joinCode: $joinCode, onJoin: { code in
                viewModel.joinSession(code: code)
                showJoinByCode = false
            })
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
        .sheet(isPresented: $showSavedSessions) {
            SavedSessionsSheet(
                sessions: viewModel.mySessions,
                onJoin: { code in
                    viewModel.joinSession(code: code)
                    showSavedSessions = false
                },
                onDelete: { session in
                    viewModel.deleteSession(session)
                }
            )
        }
    }
    
    private func loadUsername() {
        guard let userId = UserDefaults.standard.string(forKey: "PairPlan.currentUserId") else { return }
        isLoadingUsername = true
        FirestoreManager.shared.getUsername(userId: userId) { name in
            DispatchQueue.main.async {
                self.username = name ?? ""
                self.isLoadingUsername = false
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

// Новый sheet для ввода кода сессии
struct JoinByCodeSheet: View {
    @Binding var joinCode: String
    var onJoin: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String? = nil
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Ввести код сессии")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 24)
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.accentColor)
                    TextField("Код сессии", text: $joinCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .frame(maxWidth: 180)
                }
                .padding(.horizontal)
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                }
                Button(action: {
                    if joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        error = "Введите код сессии"
                    } else {
                        onJoin(joinCode)
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Вступить")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

// Новый sheet для сохранённых сессий
struct SavedSessionsSheet: View {
    let sessions: [Session]
    var onJoin: (String) -> Void
    var onDelete: (Session) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List {
                if sessions.isEmpty {
                    Text("Нет сохранённых сессий")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(sessions) { session in
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
                            Button(action: { onJoin(session.code) }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDelete(sessions[index])
                        }
                    }
                }
            }
            .navigationTitle("Сохранённые сессии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .environment(\ .editMode, .constant(.active)) // Включить свайп для удаления
        }
    }
}

// Новый компонент для квадратных быстрых кнопок
struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(foregroundColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(foregroundColor)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 110, height: 110)
            .background(RoundedRectangle(cornerRadius: 20).fill(backgroundColor))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Блок последних сессий
struct RecentSessionsBlock: View {
    let recentCodes: [String]
    let allSessions: [Session]
    var onJoin: (String) -> Void
    var body: some View {
        let recentSessions = recentCodes.compactMap { code in allSessions.first(where: { $0.code == code }) }.prefix(2)
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние сессии")
                .font(.headline)
                .padding(.horizontal, 8)
            if recentSessions.isEmpty {
                Text("Нет недавних сессий")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(Array(recentSessions), id: \ .code) { session in
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.person.crop")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.code)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(session.mode == .shared ? "Общий режим" : "Индивидуальный режим")
                                .font(.caption)
                                .foregroundColor(session.mode == .shared ? .blue : .orange)
                        }
                        Spacer()
                        Button(action: { onJoin(session.code) }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }
}
