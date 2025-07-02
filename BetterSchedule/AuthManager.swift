import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    @Published var token: String? {
        didSet {
            UserDefaults.standard.set(token, forKey: "access_token")
        }
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
                    print("Access Token: \(token)")
                    UserDefaults.standard.set(username, forKey: "username")
                    UserDefaults.standard.set(password, forKey: "password")
                    UserDefaults.standard.set(token, forKey: "access_token")
                    self.isLoggedIn = true
                    self.token = token

                case .failure(let error):
                    print("Login failed: \(error.localizedDescription)")
                    self.isLoggedIn = false
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
                    completion(true)
                case .failure(let error):
                    print("Failed to refresh token:", error.localizedDescription)
                    self.logout()
                    completion(false)
                }
            }
        }
    }
    
    func logout() {
        isLoggedIn = false
        token = nil
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "password")
        UserDefaults.standard.removeObject(forKey: "access_token")
    }
}
