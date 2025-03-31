//
//  BLE+Errors.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 21/02/22.
//

import Foundation

@objc
public class BleSdkError: NSObject {
  
  @objc public let errorCode: Int
  @objc public let errorMessage: String
  
  init(errorCode: Int, errorMessage: String) {
    self.errorCode = errorCode
    self.errorMessage = errorMessage
  }
}

public struct BLEErrorDesc {
  
  //Bluetooth scanning
  static let bluetoothOff = BleSdkError(errorCode: 1, errorMessage: BLEFailureMessage.bluetoothIsOff)
  static let bluetoothUnauthorized = BleSdkError(errorCode: 2, errorMessage: BLEFailureMessage.unauthorizedBluetoothState)
  static let bluetoothUnknown = BleSdkError(errorCode: 3, errorMessage: BLEFailureMessage.unknownBluetoothState)
  static let bluetoothResetting = BleSdkError(errorCode: 4, errorMessage: BLEFailureMessage.resettingBluetooth)
  static let bluetoothUnsupported = BleSdkError(errorCode: 5, errorMessage: BLEFailureMessage.unsupportedBluetooth)
  
  
  static let internetIsOff = BleSdkError(errorCode: 6, errorMessage: BLEFailureMessage.internetNotConnected)
  static let requestTimedOut = BleSdkError(errorCode: 7, errorMessage: BLEFailureMessage.requestTimedOut)
  static let technicalIssue = BleSdkError(errorCode: 8, errorMessage: BLEFailureMessage.serverConnectionFailed)
  
  
  static let noDeviceFound = BleSdkError(errorCode: 9, errorMessage: BLEFailureMessage.noDeviceFound)
  static let noDeviceFoundWithUniqueId = BleSdkError(errorCode: 10, errorMessage: BLEFailureMessage.noDeviceFoundWithUniqueId)
  
  
  static let connectionIsOngoing = BleSdkError(errorCode: 11, errorMessage:  BLEFailureMessage.connectionIsOngoing)
  static let scanningNotStarted = BleSdkError(errorCode: 12, errorMessage:  BLEFailureMessage.scanNotStarted)
  
  static let invalidURL = BleSdkError(errorCode: 13, errorMessage:  BLEFailureMessage.apiuUrlInvalid)
  static let initSdkFirst = BleSdkError(errorCode: 14, errorMessage: BLEFailureMessage.initSdkNotCalled)
  
  
  static let tapAndGoInsertNotCalled = BleSdkError(errorCode: 15, errorMessage: BLEFailureMessage.insertTapAndGoDataMethodNotCalled)
  static let tagMustBeNumeric = BleSdkError(errorCode: 16, errorMessage: BLEFailureMessage.tagMustBeNumeric)
  static let tapAndGoDisbled = BleSdkError(errorCode: 17, errorMessage: BLEFailureMessage.insertTapAndGoDataMethodNotCalled)
    
    
    
    //New Messages
    static let invalidEncryption =  BleSdkError(errorCode: 101, errorMessage: BLENewMessages.invalidEncryption)
    static let bleTagRequired = BleSdkError(errorCode: 102, errorMessage: BLENewMessages.bleTagRequired)
    static let invalidPunchRange = BleSdkError(errorCode: 103, errorMessage: BLENewMessages.invalidPunchRange)
    static let enableBluetooth = BleSdkError(errorCode: 201, errorMessage: BLENewMessages.enableBluetooth)
    static let bluetoothScanningRequire = BleSdkError(errorCode: 202, errorMessage: BLENewMessages.enableBluetooth)
    static let bluetoothConnectionRequire = BleSdkError(errorCode: 203, errorMessage: BLENewMessages.bluetoothConnectionRequire)
    static let invalidAdditionalInfo = BleSdkError(errorCode: 301, errorMessage: BLENewMessages.invalidAdditionalInfo)
    static let noOfFiledMustBeInInteger = BleSdkError(errorCode: 302, errorMessage: BLENewMessages.noOfFiledMustBeInInteger)
    static let fieldMustBeValidJson = BleSdkError(errorCode: 303, errorMessage: BLENewMessages.fieldMustBeValidJson)
    static let lengthMustBeInInteger = BleSdkError(errorCode: 304, errorMessage: BLENewMessages.lengthMustBeInInteger)
    static let keyMustBeNonEmpty = BleSdkError(errorCode: 305, errorMessage: BLENewMessages.keyMustBeNonEmpty)
    

}


public struct BLEFailureMessage {
  
  static let bluetoothIsOff = "Seems like your bluetooth is off. Please turn it on to continue scanning the devices."
  static let unauthorizedBluetoothState = "Unauthorised bluetooth state"
  static let unknownBluetoothState = "Unknown bluetooth state, Please check yout bluetooth to make sure it is on"
  static let resettingBluetooth = "Bluetooth is resetting"
  static let unsupportedBluetooth = "Bluetooth is not supported in your device"
  
  static let internetNotConnected = "You're not connected to the internet"
  static let requestTimedOut = "Server connection request timed out"
  static let serverConnectionFailed = "Could not connect to the server"
  static let noDeviceFound = "No bluetooth enabled device found"
  static let noDeviceFoundWithUniqueId = "Device you want to connect to is not found"
  static let connectionIsOngoing = "Previous bluetooth connection is still ongoing"
  static let scanNotStarted = "Bluetooth scanning is off, Please start scanning first to find the device nearby you"
  
  static let apiuUrlInvalid = "API URL is invalid, Please use a valid url and try again"
  static let initSdkNotCalled = "SDK has not initialised, Please initialize it by pulling down the app from the dashboard screen."
  
  static let failedToConnectPeripheral = "Could not connect to the device"
  
  static let failedToDiscoverCharacteristicForService = "Could not discover characteristic for a service"
  static let failedToDisconnectPeripheral = "Could not disconnect device"
  static let failedToDiscoverServices = "Could not discover services"
  static let failedToWriteValueForCharacteristic = "Could not write value for characteristic"
  static let failedToWriteValueForDescriptor = "Could not write value for descriptor"
  static let failedToUpdateValueForCharacteristic = "Could not update value for characteristic"
  static let failedToUpdateNotificationStateForCharacteristic = "Could not update notification state for characteristic"
  
  static let insertTapAndGoDataMethodNotCalled = "Insert tap and go data method is not called"
  static let tagMustBeNumeric = "Tag must be a numeric value"
  static let tapAndGoDisbled = "Tap and Go feature is disabled on this device"
}


public struct BLENewMessages{
    static let invalidEncryption = "Invalid encryption key."
    static let bleTagRequired = "BLETag is required and must be a numeric string (max 10 chars)."
    static let invalidPunchRange = "Invalid punchrange value: Must be 1(Low),2(Medium),or 3 (High)."
    static let enableBluetooth = "Enable Bluetooth"
    static let bluetoothScanningRequire = "Bluetooth scanning permission is required."
    static let bluetoothConnectionRequire = "Bluetooth connection permission is required."
    static let invalidAdditionalInfo = "Invalid AdditionalInfo JSON format. Refer to the provided example."
    static let noOfFiledMustBeInInteger = "no_of_fields must be an integer matching the number of fields."
    static let fieldMustBeValidJson = "fields must be a valid JSON array."
    static let lengthMustBeInInteger = "length must be an integer in all field objects."
    static let keyMustBeNonEmpty = "key must be a non-empty string."
    static let initializeSuccessFully = "Initialize Successfully."
    static let punchSuccessFully = "Punch Successfully."
    static let deviceGetSuccessFully = "Device fetch successfully."
    static let noDeviceFound = "No device found."
    
}
