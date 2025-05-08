//
//  Untitled.swift
//  BLESDKFramework
//
//  Created by Spectra-iOS on 12/03/25.
//

import Foundation
import CommonCrypto

class BLEEncryption {
    
    static private var encryptionKey: String?
    static private var peripheralId: String?
    static private var tagId: String?
    static private var deviceType: String?
    static private var deviceData: Data?
    
    static private var destinationFloor: String?
    static private var boardingFloor: String?
    static private var selectedFloor: String?
    
    static let defaultEncryptionKey = "36e4f31ccc16914a210f466e0e636f85"
    
    private var randomA: Data?
    private var randomB: Data?

    // ✅ Getter for RandomA
    func getRandomA() -> Data? {
        return randomA
    }

    // ✅ Getter for RandomB
    func getRandomB() -> Data? {
        return randomB
    }

    // ✅ Setter for RandomA
    func setRandomA(_ randomAValue: Data) {
        randomA = randomAValue
    }

    // ✅ Setter for RandomB
    func setRandomB(_ randomBValue: Data) {
        randomB = randomBValue
    }
    
    static func punchCommand() -> String {
        guard let tagId = tagId,
              let destinationFloor = destinationFloor,
              let boardingFloor = boardingFloor,
              let selectedFloor = selectedFloor else {
            return ""
        }
        
        let iTagId = UInt32(tagId) ?? 0
        let iDestFloor = UInt8(destinationFloor) ?? 0
        let iBoardFloor = UInt8(boardingFloor) ?? 0
        let iSelecFloor = UInt8(selectedFloor) ?? 0
        
        var tagBytes: [UInt8] = [
            UInt8(iTagId & 0xFF),
            UInt8((iTagId >> 8) & 0xFF),
            UInt8((iTagId >> 16) & 0xFF),
            UInt8((iTagId >> 24) & 0xFF),
            iDestFloor,
            iBoardFloor,
            iSelecFloor
        ]
        
        var arrBytes = [UInt8](repeating: 0, count: 32)
        arrBytes[0] = 0xAA
        arrBytes[1] = 19
        arrBytes[3] = 1
        arrBytes[5] = 1
        arrBytes[6] = 0xB0
        arrBytes[7] = 1
        arrBytes[8] = UInt8(tagBytes.count)
        arrBytes[9] = 0
        
        arrBytes.replaceSubrange(10..<(10 + tagBytes.count), with: tagBytes)
        
        let p = 10 + tagBytes.count
        arrBytes[p] = calculateLRC(dataPtr: arrBytes, length: p)
        arrBytes[p + 1] = 0xBB
        
        let dataToEncrypt = Data(arrBytes)
        let encryptedData = AES128Encrypt(dataToEncrypt)
        
        var result = encryptedData.base64EncodedString()
        
        if let deviceType = deviceType, ["01", "07", "1", "7"].contains(deviceType) {
            result = "\r\n" + result + "\r\n"
        }
        
        return result
    }
    
    
    static func getSecurePunchCommand(keyData: Data) -> String {
        var iTagId: UInt32 = 0
        
        // Retrieve the tag ID from Keychain
        guard let tagId = tagId,
              let destinationFloor = destinationFloor,
              let boardingFloor = boardingFloor,
              let selectedFloor = selectedFloor else {
            return ""
        }

        var tagBytes = [Int8](repeating: 0, count: 8)
        
        tagBytes[0] = Int8(iTagId & 0xFF)
        tagBytes[1] = Int8((iTagId >> 8) & 0xFF)
        tagBytes[2] = Int8((iTagId >> 16) & 0xFF)
        tagBytes[3] = Int8((iTagId >> 24) & 0xFF)

        var arrBytes = [UInt8](repeating: 0, count: 32)
        let tagByteLength = tagBytes.count

        arrBytes[0] = 0xAA  // Write header
        arrBytes[1] = UInt8((12 + tagByteLength) & 0xFF)   // Total length LSB
        arrBytes[2] = UInt8(((12 + tagByteLength) >> 8) & 0xFF)  // Total length MSB
        arrBytes[3] = 1   // Command : 1, Response : 2
        arrBytes[4] = 1   // RFU
        arrBytes[5] = 1   // Read : 0, Write : 1
        arrBytes[6] = 0xB0  // Function Code
        arrBytes[7] = 1   // Response required, Error code
        arrBytes[8] = UInt8(tagBytes.count & 0xFF)  // Payload Length LSB
        arrBytes[9] = UInt8((tagBytes.count >> 8) & 0xFF)  // Payload Length MSB

        var p = 10
        for i in 0..<tagBytes.count {
            arrBytes[p] = UInt8(bitPattern: tagBytes[i])
            p += 1
        }

        arrBytes[p] = calculateLRC(dataPtr: arrBytes, length: p)
        p += 1
        arrBytes[p] = 0xBB  // Fixed 0xBB footer

        var dataToEncrypt = Data(arrBytes)

        // Encrypt the data
        dataToEncrypt = AES128Encrypt(dataToEncrypt)

        var strResult = ""

        if !dataToEncrypt.isEmpty {
            strResult = dataToEncrypt.base64EncodedString()
        }

        if let deviceType = deviceType, ["01", "07", "1", "7"].contains(deviceType) {
            strResult = "\r\n" + strResult + "\r\n"
        }
    
        return strResult
    }

    static func calculateLRC(dataPtr: [UInt8], length: Int) -> UInt8 {
        return dataPtr.prefix(length).reduce(0, ^)
    }
    
    static func AES128Encrypt(_ dataToEncrypt: Data) -> Data {
       
        let ivBytes = [UInt8](repeating: 0, count: 16)
        
        return crypt(data: dataToEncrypt, keyData: getKeyData(dataToEncrypt), ivBytes: ivBytes, operation: CCOperation(kCCEncrypt))
    }

    
    static func AES128Decrypt(_ dataToDecrypt: Data) -> Data {
       // let keyData = hexToBytes(encryptionKey ?? defaultEncryptionKey)
        let ivBytes = [UInt8](repeating: 0, count: 16)
        
        return crypt(data: dataToDecrypt, keyData: getKeyData(dataToDecrypt), ivBytes: ivBytes, operation: CCOperation(kCCDecrypt))
    }
    
    
    static func getKeyData(_ dataToEncrypt: Data) -> Data {
        
        var keyDataBytes: Data = BLEEncryption.hexToBytes(BLEEncryption.encryptionKey ?? BLEEncryption.defaultEncryptionKey) // ✅ Default value to prevent "used before initialized"
        
        
        if let deviceData = BLEEncryption.deviceData {
            let array: [UInt8] = Array(deviceData)

            // ✅ Extract IV values
            var IV: [UInt8] = [0, 0]
            if array.count >= 2 {
                IV[0] = array[2]
                IV[1] = array[3]
            }

            // ✅ Determine Mode
            var Mode = "NULL"
            if array.count >= 3 {
                let modeChar = Character(UnicodeScalar(array[2]))
                switch modeChar {
                case "N":
                    Mode = "NULL"
                case "I":
                    Mode = "IN"
                case "O":
                    Mode = "OUT"
                default:
                    break
                }
            }

            // ✅ Append Mode to Name if not "NULL"
            var Name = "Device"
            if Mode != "NULL" {
                Name += "-\(Mode)"
            }

            // ✅ Extract Type
            var Type: UInt8 = 0
            if array.count >= 4 {
                Type = array[3]
            }

            // ✅ Check if Secure Punch is Available
            var isSecurePunchAvailable = false
            if array.count >= 5 {
                isSecurePunchAvailable = (array[4] & 0x02) == 0x02
            }

            // ✅ Check if Key is Set
            let isKeySet = !(IV[0] == 0 && IV[1] == 0)

            // ✅ Debugging Print Statements
            print("IV: \(IV)")
            print("Mode: \(Mode)")
            print("Name: \(Name)")
            print("Type: \(Type)")
            print("isSecurePunchAvailable: \(isSecurePunchAvailable)")
            print("isKeySet: \(isKeySet)")

            // ✅ Assign KeyDataBytes based on isKeySet
            keyDataBytes = isKeySet ? BLEEncryption.hexToBytes( BLEEncryption.encryptionKey ?? BLEEncryption.defaultEncryptionKey): BLEEncryption.hexToBytes(BLEEncryption.defaultEncryptionKey)
        }
        
        return keyDataBytes
    }
    
    
    
    private static func crypt(data: Data, keyData: Data, ivBytes: [UInt8], operation: CCOperation) -> Data {
        let keyBytes = [UInt8](keyData)
        let dataBytes = [UInt8](data)
        var buffer = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = CCCrypt(
            operation,
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(ccNoPadding),
            keyBytes, kCCBlockSizeAES128,
            ivBytes,
            dataBytes, data.count,
            &buffer, buffer.count,
            &numBytesEncrypted
        )
        
        return cryptStatus == kCCSuccess ? Data(buffer.prefix(numBytesEncrypted)) : Data()
    }
    
    static func setEncryptionKey(_ key: String) { encryptionKey = key }
    static func setPeripheralId(_ id: String) { peripheralId = id }
    static func setTagId(_ id: String) { tagId = id }
    static func setDeviceType(_ type: String) { deviceType = type }
    static func setDeviceData(_ data: Data) { deviceData = data }
    static func setDestinationFloor(_ floor: String) { destinationFloor = floor }
    static func setBoardingFloor(_ floor: String) { boardingFloor = floor }
    static func setSelectedFloor(_ floor: String) { selectedFloor = floor }
    
    static func hexToBytes(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
}
