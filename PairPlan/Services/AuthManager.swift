import Foundation
import FirebaseAuth

class AuthManager {
    static let shared = AuthManager()
    private init() {}

    func register(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                completion(.success(user))
            } else if let error = error {
                completion(.failure(error))
            }
        }
    }

    func login(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                completion(.success(user))
            } else if let error = error {
                completion(.failure(error))
            }
        }
    }

    func logout() throws {
        try Auth.auth().signOut()
    }

    var currentUser: User? {
        Auth.auth().currentUser
    }
} 