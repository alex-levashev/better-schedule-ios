import Security
import LocalAuthentication

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    // MARK: – Store with Face ID / Touch ID
    func saveProtected(service: String, account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.encoding }

        // Require Face ID / Touch ID *and* that a passcode is set
        var error: Unmanaged<CFError>?
        guard let access =
                SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    [.userPresence, .biometryCurrentSet],
                    &error)
        else { throw error!.takeRetainedValue() as Error }

        // Remove any old entry
        let baseQuery: [String: Any] = [
            kSecClass          as String: kSecClassGenericPassword,
            kSecAttrService    as String: service,
            kSecAttrAccount    as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        // Add the protected item
        let addQuery: [String: Any] = baseQuery.merging([
            kSecValueData       as String: data,
            kSecAttrAccessControl as String: access
        ]) { $1 }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    // MARK: – Read, prompting Face ID automatically
    func readProtected(service: String,
                       account: String,
                       prompt: String = "Unlock with Face ID") throws -> String {
        let context = LAContext()
        context.localizedReason = prompt     // text in Face ID sheet

        let query: [String: Any] = [
            kSecClass                   as String: kSecClassGenericPassword,
            kSecAttrService             as String: service,
            kSecAttrAccount             as String: account,
            kSecReturnData              as String: true,
            kSecMatchLimit              as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,       // <- link LAContext
            kSecUseOperationPrompt      as String: prompt          // iOS < 13 fallback
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str  = String(data: data, encoding: .utf8) else {
            throw KeychainError.unhandled(status)
        }
        return str
    }

    enum KeychainError: Error { case encoding; case unhandled(OSStatus) }
}
