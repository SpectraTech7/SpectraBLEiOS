//
//  BLEData.swift
//  Facility
//
//  Created by Spectra-iOS on 18/03/25.
//

import Foundation

@objc
public class BLEData: NSObject {
  
   // variable initialize
   public let code: Int
   public let message: String
   public let data: [DeviceData]?
   public let sdkVersion: String
  
  // Full initializer including DeviceData
   public init(code: Int, message: String, data: [DeviceData]?, sdkVersion: String) {
      self.code = code
      self.message = message
      self.data = data
      self.sdkVersion = sdkVersion
  }
  
  // Convenience initializer for cases without DeviceData
   public convenience init(code: Int, message: String) {
      self.init(code: code, message: message, data: nil, sdkVersion: "1.0")
  }
}

// ✅ DeviceData Struct
public struct DeviceData: Codable {
    public let deviceName: String
    public let deviceType: String
    public let deviceID: String
    public let punchTime: String
}


// ✅ BLE Event enum
public enum BLEEvent {
    case SUCCESS
    case DEVICE_LIST
    case ERROR
    case UNKNOWN
}
