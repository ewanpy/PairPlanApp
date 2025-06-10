import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Binding var isAuthenticated: Bool
    @State private var showUsernameView = false
    @State private var newUserId: String? = nil
    @State private var newUserEmail: String? = nil
    var onRegisterSuccess: ((String, String) -> Void)? = nil

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.3), Color.blue.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.accentColor)
                        .shadow(radius: 6)
                    Text(isLogin ? "Вход" : "Регистрация")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                        SecureField("Пароль", text: $password)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                            .transition(.opacity)
                            .animation(.easeInOut, value: errorMessage)
                    }
                    Button(isLogin ? "Войти" : "Зарегистрироваться") {
                        isLoading = true
                        errorMessage = nil
                        if isLogin {
                            AuthManager.shared.login(email: email, password: password) { result in
                                isLoading = false
                                switch result {
                                case .success(let user):
                                    UserDefaults.standard.set(user.uid, forKey: "PairPlan.currentUserId")
                                    isAuthenticated = true
                                case .failure(let error):
                                    if isLogin, let err = error as NSError?, err.domain == "FIRAuthErrorDomain" && (err.code == 17009 || err.code == 17008 || err.code == 17011) {
                                        errorMessage = "Неверный email или пароль. Пожалуйста, попробуйте снова."
                                    } else {
                                        errorMessage = error.localizedDescription
                                    }
                                    print("FIREBASE AUTH ERROR:", error)
                                }
                            }
                        } else {
                            AuthManager.shared.register(email: email, password: password) { result in
                                isLoading = false
                                switch result {
                                case .success(let user):
                                    UserDefaults.standard.set(user.uid, forKey: "PairPlan.currentUserId")
                                    onRegisterSuccess?(user.uid, user.email ?? "")
                                case .failure(let error):
                                    if isLogin, let err = error as NSError?, err.domain == "FIRAuthErrorDomain" && (err.code == 17009 || err.code == 17008 || err.code == 17011) {
                                        errorMessage = "Неверный email или пароль. Пожалуйста, попробуйте снова."
                                    } else {
                                        errorMessage = error.localizedDescription
                                    }
                                    print("FIREBASE AUTH ERROR:", error)
                                }
                            }
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isLoading || email.isEmpty || password.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    if isLogin {
                        Button("Зарегистрироваться") {
                            withAnimation { isLogin = false }
                        }
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                    }
                    if !isLogin {
                        Button("Войти") {
                            withAnimation { isLogin = true }
                        }
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                    }
                }
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6))
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
} 