//
//  BLE+Command.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 22/02/22.
//

import Foundation
import CoreBluetooth


extension SpectraBLE {
    
    func sendCommandOnDevice(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        
        guard let commandType = command else {
            return
        }
        
        var command: String?
       
        switch commandType {
                   
        // - - - - - - - - Set Punch Command:
        case Command.punch:
            command = BLEEncryption.punchCommand()
        }
        
        if let commandData = command?.data(using: .utf8) {
        
           // print("before writeValue")
            peripheral.writeValue(commandData, for: characteristic, type: .withResponse)
            peripheral.delegate = self
        }
    }
    
   func disconnect() {
        
       guard let `connectedPeripheral` = connectedDevice?.peripheral else {
           return
       }
       
       let index = scannedDevices.firstIndex(where: { obj in
           return connectedPeripheral.identifier.uuidString == obj.peripheralId
       })
       
       let _periId = `connectedPeripheral`.identifier.uuidString
       if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
           device.wasPunched = false
           scannedDevices.updateDevice(device)
       }
       
       if index != nil {
           connectedDevice?.wasPunched = false
           scannedDevices[index!] = connectedDevice!
       }
       centralManager?.cancelPeripheralConnection(connectedPeripheral)
    }
}
