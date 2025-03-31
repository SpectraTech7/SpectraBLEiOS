//
//  BLE+Scanning.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 21/02/22.
//

import Foundation
import CoreBluetooth

// MARK: - Ble Scanning 

extension SpectraBLE {
    
    public var state: CBManagerState? {
        return self.centralManager?.state
    }
    
    public var error: BleSdkError? {
        
        var scanError: BleSdkError? = nil
        
        guard let bluetoothState = state else {
            return BLEErrorDesc.bluetoothUnknown
        }
        
        switch bluetoothState {
            
        case .poweredOn:
            return nil
            
        case .poweredOff:
            scanError = BLEErrorDesc.bluetoothOff
            
        case .unauthorized:
            scanError = BLEErrorDesc.bluetoothUnauthorized
            
        case .unknown:
            return nil
            
        case .resetting:
            scanError = BLEErrorDesc.bluetoothResetting
            
        case .unsupported:
            scanError = BLEErrorDesc.bluetoothUnsupported
            
        default:
            return BLEErrorDesc.bluetoothUnsupported
        }
        
        return scanError
    }
}
