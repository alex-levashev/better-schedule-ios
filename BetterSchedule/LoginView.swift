import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var biometricsAvailable = false      // toggle Face ID button

    private let service = "com.yourcompany.yourapp"

    var body: some View {
        VStack(spacing: 20) {
            Text("Login").font(.largeTitle)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Log In") {
                authManager.login(username: username, password: password)
                try? KeychainHelper.shared.saveProtected(service: service,
                                                         account: "username",
                                                         value: username)
                try? KeychainHelper.shared.saveProtected(service: service,
                                                         account: "password",
                                                         value: password)
            }
            .buttonStyle(.borderedProminent)

            // Face ID / Touch ID quick login
            if biometricsAvailable {
                Button {
                    Task { await biometricLogin() }
                } label: {
                    Label("Login with Face ID", systemImage: "faceid") // Touch ID auto-swaps icon
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            biometricsAvailable = LAContext().canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, error: nil)

            // Autofill if already unlocked in keychain (e.g. during same session)
            if let savedUser = try? KeychainHelper.shared.readProtected(service: service,
                                                                        account: "username",
                                                                        prompt: "Auto-fill credentials") {
                username = savedUser
            }
        }
    }

    // MARK: – Face ID flow
    @MainActor
    private func biometricLogin() async {
        do {
            let savedUser = try KeychainHelper.shared.readProtected(service: service,
                                                                    account: "username")
            let savedPass = try KeychainHelper.shared.readProtected(service: service,
                                                                    account: "password")
            username = savedUser
            password = savedPass
            authManager.login(username: savedUser, password: savedPass)
        } catch {
            // Handle cancellations or missing creds gracefully
            print("Biometric login failed:", error)
        }
    }
}
