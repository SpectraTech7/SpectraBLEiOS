//
//  File.swift
//
//
//  Created by Manoj on 21/01/22.
//

import Foundation
import CoreBluetooth

public class BLEDevice: Equatable {
    
    private enum Advertise {
        
        case transantionLevel
        case manufactureData
        case advDataServiceUUIDs
        case advDataLocalName
        case deviceType
        
        var text: String {
            
            switch self {
                
            case .transantionLevel:
                return "kCBAdvDataTxPowerLevel"
                
            case .manufactureData:
                return "kCBAdvDataManufacturerData"
                
            case .advDataServiceUUIDs:
                return "kCBAdvDataServiceUUIDs"
                
            case .advDataLocalName:
                return "kCBAdvDataLocalName"
                
            case .deviceType:
                return "devicetype"
            }
        }
    }
    
    public let peripheral: CBPeripheral?
    public var advertisementData: [String: Any]?
    public let rssi: Int?
    public let deviceTypeInt: Int?
    public var rssiHistory: [Int]
    public var timestamp: Double
    public var isConnected: Bool = false
    public var isOutofRange: Bool = false
    public var wasPunched: Bool = false
    public var punchTimeStamp: Double?
    public var estimateDistance: Double?
    public var lastPunchTime: Double?
    public var lastPunchRSSI: Int?
    public var decisionArray:[Int]
    public var isPunchedIn: Bool = false
    public var isSecureDevice:Bool = false
    
    public init(peripheral: CBPeripheral?,
                advertisementData: [String: Any]? = nil,
                rssi: Int?,
                deviceTypeInt: Int?,
                timestamp: Double,
                isSecureDevice:Bool = true,
                rssiHistory: [Int] = [0,0,0,0,0],
                decisionArray:[Int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
                
    ) {
        
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.deviceTypeInt = deviceTypeInt
        self.timestamp = timestamp
        self.isSecureDevice = isSecureDevice
        self.rssiHistory = rssiHistory
        self.decisionArray = decisionArray
    }
    
    public static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        return lhs.peripheralId == rhs.peripheralId
    }
    
    public var IsXPReader: Bool {
        
        print()
        if self.deviceType == DeviceType.XPReader.rawValue || self.deviceType == DeviceType.XPReader2.rawValue {
            return true
        }
        
        return false
    }
    
    public var IsXPReaderWithIntCheck: Bool {
        
        if self.deviceTypeInt == 1 || self.deviceTypeInt == 01 || self.deviceTypeInt == 7 || self.deviceTypeInt == 07
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func getDeviceType() -> String
    {
        if deviceTypeInt == 0 || deviceTypeInt == 00
        {
           return DeviceType.XP_PLUS.rawValue
        }
        else if deviceTypeInt == 1 || deviceTypeInt == 01
        {
            return DeviceType.XP_READER_OLD.rawValue
        }
        else if deviceTypeInt == 2 || deviceTypeInt == 02
        {
            return DeviceType.BIOT_OLD.rawValue
        }
        else if deviceTypeInt == 3 || deviceTypeInt == 03
        {
            return DeviceType.BST3S.rawValue
        }
        else if deviceTypeInt == 4 || deviceTypeInt == 04
        {
            return DeviceType.BSC3S.rawValue
        }
        else if deviceTypeInt == 5 || deviceTypeInt == 05
        {
            return DeviceType.UST3S.rawValue
        }
        else if deviceTypeInt == 6 || deviceTypeInt == 06
        {
            return DeviceType.BIOT_NEW.rawValue
        }
        else if deviceTypeInt == 7 || deviceTypeInt == 07
        {
            return DeviceType.XP_READER_NEW_MTU.rawValue
        }
        else if deviceTypeInt == 8 || deviceTypeInt == 08
        {
            return DeviceType.XP_PRO_HID.rawValue
        }
        else if deviceTypeInt == 9 || deviceTypeInt == 09
        {
            return DeviceType.XP_PRO_SPECTRA.rawValue
        }
        
        return DeviceType.XP_PLUS.rawValue
    }
    
    
    public var midPoint: Int? {
        
        if self.rssiHistory.count == 0 {
            return self.rssi
        }
        
        let arrHistorySorted = self.rssiHistory.sorted()
        
        if arrHistorySorted.count < 8 && arrHistorySorted.count > 1 {
            
            let value = arrHistorySorted[1]
            
            if value != 0 {
                return value
            }
            
            return self.rssi
        }
        
        if arrHistorySorted[6] == 0 || arrHistorySorted[7] == 0 {
            return self.rssi
        }
        
        return (arrHistorySorted[6] + arrHistorySorted[7])/2
    }
    
    public var manufactureData: Data? {
        
        guard let manufData = self.advertisementData?[Advertise.manufactureData.text] as? Data else {
            return nil
        }
        
        return manufData
    }
    
    public var manufDataString: String? {
        if let data = manufactureData as Data? { // Convert NSData to Data
            return data.hexRepresentationWithSpaces_AS()
        }
        return nil
    }
    
    public var deviceName: String? {
        
        guard let name = self.advertisementData?[Advertise.advDataLocalName.text] as? String else {
            return nil
        }
        return name
    }
    
    public var peripheralId: String? {
        return self.peripheral?.identifier.uuidString
    }
    
    public var inOutFlag: String? {
        
        guard let count = manufDataString?.count, count > 10 else {
            return nil
        }
        
        return manufDataString?.substring(with: 8..<10)
    }
    
    public var deviceType: String? {
        
        guard let count = manufDataString?.count, count > 12 else {
            return nil
        }
        
        return manufDataString?.substring(with: 10..<12)
    }
    
    public var tapValue: String? {
        
        guard let count = manufDataString?.count, count >= 14 else {
            return nil
        }
        
        return manufDataString?.substring(with: 12..<13)
    }
    
    public var transactionLevel: Int? {
        
        guard let result = self.advertisementData?[Advertise.advDataLocalName.text] as? Int else {
            return nil
        }
        
        return result
    }
}


extension Data {
    func hexRepresentationWithSpaces_AS() -> String {
        return self.map { String(format: "%02x", $0) }.joined(separator: " ") // Added spaces for clarity
    }
}
