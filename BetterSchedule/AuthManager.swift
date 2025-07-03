import Foundation
import Combine

/// Centralised authentication state for the app.
final class AuthManager: ObservableObject {

    @Published var authError: String?
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }

    @Published var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "access_token") }
    }

    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.token = UserDefaults.standard.string(forKey: "access_token")
    }

    func login(username: String, password: String) {
        TokenService.getToken(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    UserDefaults.standard.set(username, forKey: "username")
                    UserDefaults.standard.set(password, forKey: "password")

                    self.token = token
                    self.isLoggedIn = true
                    self.authError = nil  // clear old error

                case .failure(let error):
                    self.token = nil
                    self.isLoggedIn = false
                    self.authError = error.localizedDescription
                    print("Login failed:", error.localizedDescription)
                }
            }
        }
    }

    func refreshToken(completion: @escaping (Bool) -> Void) {
        TokenService.refreshTokenWithStoredCredentials { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newToken):
                    self.token = newToken
                    self.isLoggedIn = true
                    self.authError = nil
                    completion(true)

                case .failure(let error):
                    self.logout()  // clears state
                    self.authError = error.localizedDescription
                    print("Token refresh failed:", error.localizedDescription)
                    completion(false)
                }
            }
        }
    }

    // MARK: – Logout
    func logout() {
        isLoggedIn = false
        token = nil
        authError = nil

        // Wipe persisted creds
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "password")
        UserDefaults.standard.removeObject(forKey: "access_token")
    }
}
