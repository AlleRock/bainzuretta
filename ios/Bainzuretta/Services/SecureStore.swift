import Foundation
import Security

struct SecureStore {
    private let service = "it.allerock.Bainzuretta"
    func read<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecureError.failure(status) }
        return try JSONDecoder().decode(type,from:data)
    }
    func write<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key]
        let update = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if update == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(insert as CFDictionary,nil)
            guard added == errSecSuccess else { throw SecureError.failure(added) }
        } else if update != errSecSuccess { throw SecureError.failure(update) }
    }
    func delete(_ key: String) throws {
        let status = SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureError.failure(status) }
    }
    enum SecureError: Error, LocalizedError {
        case failure(OSStatus)
        var errorDescription: String? {
            if case .failure(let status) = self { return "Portachiavi non disponibile (codice \(status)). Riapri l’app; se il problema persiste, segnala questo codice." }
            return nil
        }
    }
}
