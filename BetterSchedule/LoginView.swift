import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var biometricsAvailable = false
    @State private var showErrorAlert = false

    private let service = "com.yourcompany.yourapp"

    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .padding(.top)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Log In") {
                login()
            }
            .buttonStyle(.borderedProminent)

            if biometricsAvailable {
                Button {
                    Task { await biometricLogin() }
                } label: {
                    Label("Login with Face ID", systemImage: "faceid")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear(perform: configureBiometrics)
        .onReceive(authManager.$authError) { error in
            showErrorAlert = error != nil
        }
        .alert("Login Failed",
               isPresented: $showErrorAlert,
               actions: {
                   Button("OK", role: .cancel) {
                       authManager.authError = nil
                   }
               },
               message: {
                   Text(authManager.authError ?? "Unknown error")
               })
    }

    private func configureBiometrics() {
        biometricsAvailable = LAContext()
            .canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        // Optional: Autofill if already unlocked in session
        if let savedUser = try? KeychainHelper.shared.readProtected(service: service,
                                                                    account: "username",
                                                                    prompt: "Auto-fill credentials") {
            username = savedUser
        }
    }

    private func login() {
        authManager.login(username: username, password: password)

        do {
            try KeychainHelper.shared.saveProtected(service: service, account: "username", value: username)
            try KeychainHelper.shared.saveProtected(service: service, account: "password", value: password)
        } catch {
            print("Keychain save failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func biometricLogin() async {
        do {
            let savedUser = try KeychainHelper.shared.readProtected(service: service, account: "username")
            let savedPass = try KeychainHelper.shared.readProtected(service: service, account: "password")
            username = savedUser
            password = savedPass
            authManager.login(username: savedUser, password: savedPass)
        } catch {
            authManager.authError = "Biometric login failed: \(error.localizedDescription)"
        }
    }
}
