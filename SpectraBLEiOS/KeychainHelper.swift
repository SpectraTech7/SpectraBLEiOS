//  KeychainHelper.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 24/02/22.
//

import Foundation
import Security


final class KeychainHelper {
    
    private let SecGenericPassword: String = kSecClassGenericPassword as String
    private let SecMatchLimit: String = kSecMatchLimit as String
    private let SecReturnData: String = kSecReturnData as String
    private let SecReturnPersistentRef: String = kSecReturnPersistentRef as String
    private let SecValueData: String = kSecValueData as String
    private let SecAttrAccessible: String = kSecAttrAccessible as String
    private let SecClass: String = kSecClass as String
    private let SecAttrService: String = kSecAttrService as String
    private let SecAttrGeneric: String = kSecAttrGeneric as String
    private let SecAttrAccount: String = kSecAttrAccount as String
    private let SecAttrAccessGroup: String = kSecAttrAccessGroup as String
    private let SecReturnAttributes: String = kSecReturnAttributes as String

    
    private static let defaultService = "spectrakeychainwrapper"
    
    static let shared = KeychainHelper()
    private init() {}
    
    @discardableResult
    public func setValue(_ value: String, forKey key: String) -> Bool {
        
        if let data = value.data(using: .utf8) {
        
            let query = [
                SecValueData: data,
                SecClass: SecGenericPassword,
                SecAttrService: KeychainHelper.defaultService,
                SecAttrAccount: key,
            ] as CFDictionary
            
            // Add data in query to keychain
            let status = SecItemAdd(query, nil)
            
            if status == errSecSuccess {
                // Print out the error
              //  print("Saved successfully")
                
            } else if status == errSecDuplicateItem {
                //Call update here
                updateValue(value, forKey: key)
            }
        }
        
        return false
    }
    
    @discardableResult
    public func updateValue(_ value: String, forKey key: String) -> Bool {
        
        if let data = value.data(using: .utf8) {
            
            let query = [
                SecClass: SecGenericPassword,
                SecAttrService: KeychainHelper.defaultService,
                SecAttrAccount: key,
            ] as CFDictionary
            
            let attributesToUpdate = [kSecValueData: data] as CFDictionary
            
            let status: OSStatus = SecItemUpdate(query, attributesToUpdate)
            
            if status == errSecSuccess {
                return true
            }
        }
        return false
    }
    
    @discardableResult
    public func removeValue(forKey key: String) -> Bool {
        
        let query = [
            kSecAttrService: KeychainHelper.defaultService,
            kSecAttrAccount: key,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        // Delete
        let status: OSStatus = SecItemDelete(query)

        if status == errSecSuccess {
            return true
        }
        
        return false
    }
    
    @discardableResult
    public func value(forKey key: String) -> String? {
        
        let query = [
            SecClass: SecGenericPassword,
            SecAttrService: KeychainHelper.defaultService,
            SecAttrAccount: key,
            SecReturnData: true,
            SecMatchLimit: kSecMatchLimitOne as String
            
        ] as CFDictionary
        
        var result: AnyObject?
        let status =  SecItemCopyMatching(query, &result)
        
        if status == noErr {
            if let `resultData` = (result as? Data) {
                return String(decoding: resultData, as: UTF8.self)
            }
        }
        return nil
    }
    
}
