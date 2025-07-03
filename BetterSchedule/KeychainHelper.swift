import Security
import LocalAuthentication

/// One tiny, self-contained helper for storing **small strings**
/// (tokens, usernames, passwords …) protected by Face ID / Touch ID
/// and a device passcode.
/// –  Uses `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` so data
///    never syncs to iCloud and is wiped on device passcode change.
/// –  Requires *current* biometrics (`.biometryCurrentSet`) to prevent
///    a newly-enrolled face/finger from unlocking the old item.
final class KeychainHelper {

    // MARK: Singleton
    static let shared = KeychainHelper()
    private init() {}

    // MARK: Public API
    /// Save (or update) a string protected by Face/Touch ID.
    @discardableResult
    func saveProtected(
        service: String,
        account: String,
        value: String
    ) throws -> Bool {
        guard let data = value.data(using: .utf8) else { throw KeychainError.encoding }

        var unmanagedError: Unmanaged<CFError>?
        guard
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                [.userPresence, .biometryCurrentSet],
                &unmanagedError)
        else {
            throw unmanagedError!.takeRetainedValue() as Error
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access,
        ]

        // Try to update first; if item doesn’t exist, add it.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return true  // updated
        case errSecItemNotFound:
            // Need to add a fresh item
            let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
            return true  // added
        default:
            throw KeychainError.unhandled(updateStatus)
        }
    }

    /// Read a protected value, prompting Face/Touch ID automatically.
    func readProtected(
        service: String,
        account: String,
        prompt: String = "Unlock with Face ID"
    ) throws -> String {
        let context = LAContext()
        context.localizedReason = prompt

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
            kSecUseOperationPrompt as String: prompt,  // iOS < 13 fallback
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
            let data = item as? Data,
            let string = String(data: data, encoding: .utf8)
        else {
            if status == errSecItemNotFound { throw KeychainError.notFound }
            throw KeychainError.unhandled(status)
        }
        return string
    }

    /// Delete a protected item. Returns `true` if something was removed.
    @discardableResult
    func delete(service: String, account: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess: return true
        case errSecItemNotFound: return false  // nothing to delete
        default: throw KeychainError.unhandled(status)
        }
    }

    // MARK: Error
    enum KeychainError: Error {
        case encoding
        case notFound
        case unhandled(OSStatus)

        var localizedDescription: String {
            switch self {
            case .encoding: return "String-to-data conversion failed."
            case .notFound: return "Item not found in Keychain."
            case .unhandled(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return message
                }
                return "Keychain error (\(status))."
            }
        }
    }
}
