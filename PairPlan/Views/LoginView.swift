import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    var onAuthSuccess: (() -> Void)?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(isRegistering ? "Регистрация" : "Вход")
                    .font(.largeTitle)
                    .bold()
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                SecureField("Пароль", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                Button(isRegistering ? "Зарегистрироваться" : "Войти") {
                    isLoading = true
                    errorMessage = nil
                    if isRegistering {
                        Auth.auth().createUser(withEmail: email, password: password) { result, error in
                            isLoading = false
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else {
                                onAuthSuccess?()
                            }
                        }
                    } else {
                        Auth.auth().signIn(withEmail: email, password: password) { result, error in
                            isLoading = false
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else {
                                onAuthSuccess?()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
                Button(isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться") {
                    isRegistering.toggle()
                    errorMessage = nil
                }
                .font(.footnote)
                Spacer()
            }
            .padding()
        }
    }
} 