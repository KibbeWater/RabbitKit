//
//  KeychainService.swift
//
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation
import KeychainAccess

public class KeychainService {
    let keychain: Keychain

        init() {
            // Initialize Keychain with the service name and access group
            keychain = Keychain(service: "com.kibbewater.Rabbit", accessGroup: "89625ZHN6X.com.kibbewater.Rabbit")
        }

        // Save a string to Keychain
        func save(_ value: String, forKey key: String) {
            do {
                try keychain.set(value, key: key)
            } catch let error {
                print("Error saving value: \(error.localizedDescription)")
            }
        }

        // Read a string from Keychain
        func read(forKey key: String) -> String? {
            do {
                let value = try keychain.get(key)
                return value
            } catch let error {
                print("Error reading value: \(error.localizedDescription)")
                return nil
            }
        }

        // Delete a string from Keychain
        func delete(forKey key: String) {
            do {
                try keychain.remove(key)
            } catch let error {
                print("Error deleting value: \(error.localizedDescription)")
            }
        }
}
