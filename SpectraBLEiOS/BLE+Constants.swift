//
//  File.swift
//
//
//  Created by Manoj on 24/01/22.
//

import Foundation

public enum DeviceType: String {
  
  case INVALID = "-1"
  case XP_PLUS = "0"
  case XP_READER_OLD = "1"
  case BIOT_OLD = "2"
  case BST3S = "3"
  case BSC3S = "4"
  case UST3S = "5"
  case BIOT_NEW = "6"
  case XP_READER_NEW_MTU = "7"
  case XP_PRO_HID = "8"
  case XP_PRO_SPECTRA = "9"
  case DITM = "99"
  case XPReader = "01"
  case XPReader2 = "07"
  case Biot = "02"
  case Biostamp3s = "03"
  case Biosrible3s = "04"
}

public struct DeviceConstant {
  
  static let CReadingCount: Int = 20 // 15
  
  static let CIv = "8080808080808080"
  static let CDeviceUDID = "3a4e2bed-0000-1000-8000-00805f9b34fb"
  
  static let CServiceUuid = "ED2B4E3A-2820-492F-9507-DF165285E831"
  static let CServiceUuidXPReader = "49535343-FE7D-4AE5-8FA9-9FAFD205E455"
  
  static let CCharacteristicUuid = "ED2B4E3B-2820-492F-9507-DF165285E831"
  static let CCharacteristicUuidXPReader = "49535343-8841-43F4-A8D4-ECBE34729BB3"
  
  static let CCharacteristicUuidForResponse = "ED2B4E3C-2820-492F-9507-DF165285E831"
  static let CCharacteristicUuidForResponseXPReader = "49535343-1E4D-4BD9-BA61-23C647249616"
  
  static let CEncryptionKey = "encryptionkey"
}


public enum Command {
  case punch
}
