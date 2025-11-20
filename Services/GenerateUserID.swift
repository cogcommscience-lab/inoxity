//
//  GenerateUserID.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import Foundation
import Security

final class IdentityService {
    static let shared = IdentityService()

    // Use something stable for your app/service name (often your bundle id)
    private let service = "com.keeapp.identity"
    private let account = "user_id"

    private(set) var userId: UUID

    private init() {
        if let existing = Keychain.readString(service: service, account: account),
           let id = UUID(uuidString: existing) {
            userId = id
        } else {
            let newId = UUID()
            _ = Keychain.saveString(newId.uuidString, service: service, account: account)
            userId = newId
        }
    }

    // For QA resets only (don’t ship this in production)
    #if DEBUG
    func resetForTesting() {
        Keychain.delete(service: service, account: account)
        let newId = UUID()
        _ = Keychain.saveString(newId.uuidString, service: service, account: account)
        userId = newId
    }
    #endif
}

// Minimal Keychain helpers for a single string value
enum Keychain {
    static func saveString(_ value: String, service: String, account: String) -> Bool {
        let data = Data(value.utf8)
        // Remove existing
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func readString(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
