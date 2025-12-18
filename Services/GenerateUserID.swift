//
//  GenerateUserID.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import Foundation // gives UUID, Data, String, etc.
import Security // gives Keychain APIs like SecItemAdd, SecItemCopyMatching, SecItemDelete

// No subclassing and setting global status (i.e., shared)
final class IdentityService {
    static let shared = IdentityService()
    
    // Adresses for my Keychain item
    private let service = Bundle.main.bundleIdentifier ?? "com.kee.inoxityapp"
    private let account = "installation_id"
    
    private(set) var userId: UUID
    
    // if user ID exists in Keychain, reuse it
    private init() {
        if let existing = Keychain.readString(service: service, account: account),
           let id = UUID(uuidString: existing) {
            userId = id
        } else {
            let newId = UUID() // create new ID if not in Keychain
            _ = Keychain.saveString(newId.uuidString, service: service, account: account)
            userId = newId
        }
    }
    
    // Minimal Keychain helpers for a single string value
    enum Keychain {
        // converts string to data
        static func saveString(_ value: String, service: String, account: String) -> Bool {
            let data = Data(value.utf8)
            // Remove existing
            delete(service: service, account: account)
            
            // builds the Keychain query
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecValueData as String: data
            ]
            // returns true if ID was added to Keychain
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        }
        
        // Searches and reads the user ID from Keychain
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
        
        // Removes the Keychain entry if present
        static func delete(service: String, account: String) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
