import SwiftUI

struct UsernameView: View {
    let userId: String
    let email: String
    var onComplete: () -> Void
    
    @State private var username: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.3), Color.blue.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "person.text.rectangle")
                        .resizable()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.accentColor)
                        .shadow(radius: 6)
                    Text("Придумайте уникальный Username")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                            .transition(.opacity)
                            .animation(.easeInOut, value: errorMessage)
                    }
                    Button("Сохранить Username") {
                        saveUsername()
                    }
                    .disabled(isLoading || username.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isLoading || username.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6))
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
    
    private func saveUsername() {
        isLoading = true
        errorMessage = nil
        // Проверка уникальности username
        let usersRef = FirestoreManager.shared.usersCollection()
        usersRef.whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = "Ошибка: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            if let docs = snapshot?.documents, !docs.isEmpty {
                self.errorMessage = "Этот Username уже занят. Попробуйте другой."
                self.isLoading = false
                return
            }
            // Username уникален, сохраняем
            usersRef.document(userId).setData([
                "email": email,
                "username": username
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
                    } else {
                        onComplete()
                    }
                    self.isLoading = false
                }
            }
        }
    }
} 