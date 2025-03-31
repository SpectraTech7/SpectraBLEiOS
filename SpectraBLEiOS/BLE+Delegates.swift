//
//
//  Created by Manoj on 11/01/22.
//

import Foundation
import CoreBluetooth
import AudioToolbox
import CoreLocation

//MARK: - BLE central manager delegate methods

extension SpectraBLE: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if self.error != nil {
            bleManagerDelegate?.onScanFailure(error: error!)
            return
        }
        
        if central.state == .poweredOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                       guard let self = self, let callback = self.globalCallback else {
                           return
                       }
                       self.startScan(callback: callback) // Explicitly using 'self'
                }
        }
    }
    
    func getNearestDevice() -> BLEDevice? {
        return scannedDevices.min(by: { $0.estimateDistance ?? 0  > $1.estimateDistance ?? 0 }) 
    }
    
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        if RSSI.intValue > 60
        {
            return
        }
        
        let deviceId = peripheral.identifier.uuidString
      
        var midValue: Int = 0
        
//        if BLETapAndGodDefaultValue.shared.isAllowedPunch != 1 {
//            return
//        }
        
        if advertisementData.isBOITDevice() {
            return
        }
        
        if advertisementData.getDeviceType() == -1  {
            return
        }
        
        
        var rssiValue = abs(RSSI.intValue)
        
        if RSSI.intValue > 0 {
            return
        }

        // Process each device on a separate background thread
        DispatchQueue.global(qos: .userInitiated).async {
            
        let deviceName = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
        
        let isSecure = advertisementData.isSecureDevice()
          
        let device = BLEDevice(peripheral: peripheral,
                               advertisementData: advertisementData,
                               rssi: RSSI.intValue,
                               deviceTypeInt: advertisementData.getDeviceType(),
                               timestamp: Date().timeIntervalSince1970,
                               isSecureDevice: isSecure,
                               rssiHistory: [RSSI.intValue,
                                             0,
                                             0,
                                             0,
                                             0],
                               decisionArray: self.DecisionArray
                                    )
            
            
            // Check if the device already exists in lScannedDevices
            if let existingDeviceIndex = self.lScannedDevices.firstIndex(where: { $0.peripheralId == device.peripheralId }) {
                
                DispatchQueue.main.async {
                    
                    if self.lScannedDevices.count > 0
                    {
                        let existingDevice = self.lScannedDevices[existingDeviceIndex]
                        
                        // Keep only the last 20 samples
                        if existingDevice.rssiHistory.count > 5 {
                            existingDevice.rssiHistory.removeFirst()
                        }
                        existingDevice.rssiHistory.append(RSSI.intValue)
                        self.lScannedDevices[existingDeviceIndex] = existingDevice
                        
                        // Get the median RSSI value from updated history
                        midValue = self.getSmoothedRssi(existingDevice.rssiHistory)
                        
                        if let device = self.scannedDevices.first(where: { $0.peripheralId == existingDevice.peripheralId }) {
                            device.advertisementData = advertisementData
                            self.scannedDevices.updateDevice(device)
                        }
                        
                        self.processPunching(for: deviceId, device: existingDevice, midValue: midValue)
                    }
                   
                }
                
            } else {
                // New device, initialize properly
                let newDevice = BLEDevice(
                    peripheral: peripheral,
                    advertisementData: advertisementData,
                    rssi: RSSI.intValue,
                    deviceTypeInt: advertisementData.getDeviceType(),
                    timestamp: Date().timeIntervalSince1970, isSecureDevice: isSecure,
                    rssiHistory: [RSSI.intValue,
                                  0,
                                  0,
                                  0,
                                  0],
                    decisionArray: self.DecisionArray
                )
                
                let timestamp = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "mm:ss:SSS"  // Minutes:Seconds:Milliseconds
                let formattedTime = dateFormatter.string(from: timestamp)

                DispatchQueue.main.async {
    
                    midValue = self.getSmoothedRssi(newDevice.rssiHistory) ?? -99
                    
                    if !self.lScannedDevices.contains(where: { $0.peripheralId == newDevice.peripheralId }) {
                        self.lScannedDevices.append(newDevice)
                    }
                    self.processPunching(for: deviceId, device: newDevice, midValue: midValue)
                          
                }
            }
        }
    }

    public func processPunching(for deviceId: String, device: BLEDevice, midValue: Int){
        
        let timestamp = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss:SSS"  // Minutes:Seconds:Milliseconds
        let formattedTime = dateFormatter.string(from: timestamp)
        let txPowerLevel = device.advertisementData?["kCBAdvDataTxPowerLevel"] as? Int ?? 0
        var threshold:Int = 0
        
        
        if ((txPowerLevel != 0 && txPowerLevel > -21) && (txPowerLevel != 0 && txPowerLevel < 21))
        {
            threshold = self.getEntryThreshold(device: device) + txPowerLevel
        }
        else
        {
            threshold = self.getEntryThreshold(device: device)
        }
        
    
        if deviceId == self.currentPunchedDeviceId {
            
            // Avoid repunching if RSSI fluctuation is small
            if let lastRSSI = self.currentPunchedRSSI, abs(lastRSSI - midValue) <= self.rssiStabilityMargin {
                return
            }
           
           
            // If RSSI drops below exitRSSI, clear current device
            if midValue <= threshold {
               
                self.hasVibrated = false  // Prevent continuous vibration
                device.decisionArray.append(2)
                device.decisionArray.removeFirst()
                            
                self.currentPunchedDeviceId = nil
                self.currentPunchedRSSI = nil
                
                if device.decisionArray.allSatisfy({ $0 == 2 }) {
                    if scannedDevices.contains(where: { $0.peripheralId == device.peripheralId }) {
                        
                        if let index = scannedDevices.firstIndex(where: { $0.peripheralId == device.peripheralId }) {
                            scannedDevices.remove(at: index)
                        }
                    }
                    
                }
              
               // print("device goes outside")
                UserDefaults.standard.setValue( Date().timeIntervalSince1970, forKey: "LastPunchTime")
                UserDefaults.standard.set(false, forKey: "wasPunched")
                UserDefaults.standard.synchronize()
            }else if midValue >= threshold {
                if self.currentPunchedDeviceId != deviceId {
                    self.currentPunchedDeviceId = deviceId
                    self.currentPunchedRSSI = midValue
                }
                
                device.decisionArray.append(1)
                device.decisionArray.removeFirst()
            
                 if device.decisionArray.count >= DecisionArrayLength && device.decisionArray.allSatisfy({ $0 != 0 })
                {
                     // Run makeFinalDecision on a background thread
                       DispatchQueue.global(qos: .userInitiated).async {
                           self.makeFinalDecision(device, midValue: midValue)
                       }
                }
            }
            else
            {
              
                // Maintain only the last 20 values
                device.decisionArray.append(1)
                device.decisionArray.removeFirst()
                
                 if device.decisionArray.count >= DecisionArrayLength && device.decisionArray.allSatisfy({ $0 != 0 })
                {
                       DispatchQueue.global(qos: .userInitiated).async {
                           self.makeFinalDecision(device, midValue: midValue)
                       }
                 }
            }
            
            return
            
        }
        
        if abs(midValue) <= abs(threshold) {
            if self.currentPunchedDeviceId != deviceId {

            self.currentPunchedDeviceId = deviceId
            self.currentPunchedRSSI = abs(midValue)}
            
            device.decisionArray.append(1)
            device.decisionArray.removeFirst()
            
             if device.decisionArray.count >= DecisionArrayLength && device.decisionArray.allSatisfy({ $0 != 0 })
            {
                 // Run makeFinalDecision on a background thread
                   DispatchQueue.global(qos: .userInitiated).async {
                       self.makeFinalDecision(device, midValue: midValue)
                   }
            }
          
        }else{
           
            // Maintain only the last 20 values
            device.decisionArray.append(2)
            device.decisionArray.removeFirst()
            
            if device.decisionArray.allSatisfy({ $0 == 2 }) {
                
                if scannedDevices.contains(where: { $0.peripheralId == device.peripheralId }) {
                    
                    if let index = scannedDevices.firstIndex(where: { $0.peripheralId == device.peripheralId }) {
                        scannedDevices.remove(at: index)
                    }
                }
            }
            
            
            if device.decisionArray.count >= DecisionArrayLength && device.decisionArray.allSatisfy({ $0 != 0 })
            {
                  DispatchQueue.global(qos: .userInitiated).async {
                      self.makeFinalDecision(device, midValue: midValue)
                  }
            }
        
            return
        }
    }
    
    func makeFinalDecision(_ device: BLEDevice,midValue: Int) {
        
        var wPunched :Bool = false
        
        // Convert timestamp to minutes, seconds, and milliseconds
        let timestamp = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "ss:SSS"  // Seconds:Milliseconds only
            let formattedTime = dateFormatter.string(from: timestamp)
        
            if device.decisionArray.allSatisfy({ $0 == 1 }) {
                
                if !scannedDevices.contains(where: { $0.peripheralId == device.peripheralId }) {
                        scannedDevices.append(device)
                    }
                
                self.lastTapTime = Date().timeIntervalSince1970
                
                isConnect = true
                
                if let wasPunched = UserDefaults.standard.value(forKey: "wasPunched") as? Bool {
                    wPunched = wasPunched
                }
                
                //TODO: Tap & Go Logic
                if self.isTapAndGoEnabled {
                    
                    self.tagId = BLETapAndGodDefaultValue.shared.tagId
                    self.tapAndGoBoardingFloor = BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor
                    self.tapAndGoSelectedFloor = BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor
                    self.tapAndGoDestinationFloor = BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor
                    self.sensitityLevel = BLETapAndGodDefaultValue.shared.sensitivity
                    
                    
                    if wPunched == false  {
                        
                        // Reset decisionArray to 0 for next cycle
                        UserDefaults.standard.set(true, forKey: "wasPunched")
                        UserDefaults.standard.synchronize()
                        wPunched = true
                        
                        DispatchQueue.main.async {
                            self.punchQueue.async {
                                self.makePunch(tagId: self.tagId,
                                               destinationFloor: self.tapAndGoDestinationFloor,
                                               boardingFloor: self.tapAndGoBoardingFloor,
                                               selectedFloor: self.tapAndGoSelectedFloor,
                                               deviceUniqueId: "")
                                
                            }
                        }
                    }
                }
            }
            else {
              
            }
    }
    
    
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
       
        let connectTime = Date().timeIntervalSince1970
     
        isConnectionOngoing = false
        peripheral.delegate = self
       
        
        if peripheral.state == .connected {
            //connectedPeripheral = peripheral
            //vibrate phone
            peripheral.readRSSI()
            AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
        }
        
        if let _connectedDevice = scannedDevices.currentDevice(forPeripheralId: peripheral.identifier.uuidString) {
          //  print(_connectedDevice)
          //  print(_connectedDevice.IsXPReader)
        }
        
        if let connectedDevice = connectedDevice, connectedDevice.IsXPReaderWithIntCheck {
            
            if peripheral.services != nil {
                self.peripheral(peripheral, didDiscoverServices: nil)
               
            } else {
                peripheral.discoverServices([CBUUID(string: DeviceConstant.CServiceUuidXPReader)])
            }
            
            return
        }
        
        let discoverStartTime = Date().timeIntervalSince1970
        
        if peripheral.services != nil {
            self.peripheral(peripheral, didDiscoverServices: nil)
        } else {
           
            peripheral.discoverServices([CBUUID(string: DeviceConstant.CServiceUuid)])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if error != nil {
        }
        
        let _periId = peripheral.identifier.uuidString
        if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
            device.wasPunched = false
            scannedDevices.updateDevice(device)
        }
        
        isConnectionOngoing = false
        
        guard let callback = globalCallback else {
            return
        }
        
        startScan(callback: callback)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        if error != nil {
        
        }
        
        isConnect = false
    }
    
    public func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        
    }
    
    public func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        
        if let row = self.scannedDevices.firstIndex(where: { ($0.peripheralId ?? "") == peripheral.identifier.uuidString }) {
            
            let foundDictionary = self.scannedDevices[row]
            foundDictionary.lastPunchRSSI = abs(RSSI.intValue)
            foundDictionary.lastPunchTime = Date().timeIntervalSince1970
            self.scannedDevices[row] = foundDictionary
        }
        
    }
    
    //MARK: - ESTIMATE DISTANCE
    public func estimateDistance(fromRSSI rssi: Int, txPower: Int) -> Double {
//        let txPower = -59 // Reference RSSI at 1 meter. Adjust based on calibration.
        if rssi == 0 {
            return -1.0 // RSSI not available
        }
        
        let ratio = Double(rssi) / Double(txPower)
        if ratio < 1.0 {
            return pow(ratio, 10)
        } else {
            return (0.89976) * pow(ratio, 7.7095) + 0.111
        }
    }
}


//MARK: - BLE peripheral delegate methods
//MARK: -

extension SpectraBLE: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if error != nil {
            
            print("\n")
            print("didDiscoverServices: ", error)
            print("\n")
            
            let _periId = peripheral.identifier.uuidString
            if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
                device.wasPunched = false
                scannedDevices.updateDevice(device)
            }
            
            return
        }
        
        let discoverEndTime = Date().timeIntervalSince1970
        
        if let pServices = peripheral.services {
            
            for service in pServices {
                
                if let connectedDevice = connectedDevice, connectedDevice.IsXPReader {
                    
                    peripheral.discoverCharacteristics([CBUUID(string: DeviceConstant.CCharacteristicUuidXPReader), CBUUID(string: DeviceConstant.CCharacteristicUuidForResponseXPReader)], for: service)
                    
                    
                } else {
                    
                    peripheral.discoverCharacteristics([CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse), CBUUID(string: DeviceConstant.CCharacteristicUuid)], for: service)
                    
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        
        if error != nil {
            
            print("\n")
            print("didDiscoverCharacteristicsFor: ", error)
            print("\n")
            
            let _periId = peripheral.identifier.uuidString
            if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
                device.wasPunched = false
                scannedDevices.updateDevice(device)
            }
        
        }
        
        let charDiscoverTime = Date().timeIntervalSince1970
  
        
        guard let arrChars = service.characteristics else {
            
            let _periId = peripheral.identifier.uuidString
            if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
                device.wasPunched = false
                scannedDevices.updateDevice(device)
            }
            
            return
        }
    
        for characteristic in arrChars {
            
            if let connectedDevice = connectedDevice, connectedDevice.IsXPReader {
                
                if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidXPReader) {
                    
                    peripheral.setNotifyValue(true, for: characteristic)
                    if isConnect == true{
                        sendCommandOnDevice(characteristic: characteristic, peripheral: peripheral)
                    }
                    else
                    {
                        disconnect()
                    }
                    
                } else if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponseXPReader) {
                    
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                    
                }
                
            } else {
                
                if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuid) {
                    
                    peripheral.setNotifyValue(true, for: characteristic)

                    if isConnect == true{
                        sendCommandOnDevice(characteristic: characteristic, peripheral: peripheral)
                    }
                    else
                    {
                        disconnect()
                    }
                    
                } else if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse) {
                    
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                    
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if error != nil {
            let _periId = peripheral.identifier.uuidString
            if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
                device.wasPunched = false
                scannedDevices.updateDevice(device)
            }
            return
        }
    
        let _periId = peripheral.identifier.uuidString
        if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
            device.wasPunched = false
            scannedDevices.updateDevice(device)
        }
        
        isConnectionOngoing = false
        if peripheral.state == .connected {
            self.disconnect()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        
        if error != nil {
        }
        
        let _periId = peripheral.identifier.uuidString
        if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
            device.wasPunched = false
            scannedDevices.updateDevice(device)
        }
        
        isConnectionOngoing = false
        if peripheral.state == .connected {
            disconnect()
        }
    }
    
//    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        
//        if error != nil {
//            
//            let _periId = peripheral.identifier.uuidString
//            if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
//                device.wasPunched = false
//                scannedDevices.updateDevice(device)
//            }
//        }
//        let _periId = peripheral.identifier.uuidString
//        if let device = scannedDevices.currentDevice(forPeripheralId: _periId) {
//            device.wasPunched = false
//            scannedDevices.updateDevice(device)
//        }
//    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error {
            let periId = peripheral.identifier.uuidString
            if let deviceIndex = scannedDevices.firstIndex(where: { $0.peripheralId == periId }) {
                scannedDevices[deviceIndex].wasPunched = false
            }
            print("Error updating characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let characteristicValue = characteristic.value else {
            print("Characteristic value is nil")
            return
        }

        let periId = peripheral.identifier.uuidString
        if let deviceIndex = scannedDevices.firstIndex(where: { $0.peripheralId == periId }) {
            scannedDevices[deviceIndex].wasPunched = false
        }

        // Check if characteristic is the expected response
        if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse) {
            
            let data = characteristicValue

            // Check if the device is secure
            if let foundDevice = scannedDevices.first(where: { $0.peripheralId == periId }),
               foundDevice.isSecureDevice == true {
                
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseStr)")
                    
                    if let commaIndex = responseStr.firstIndex(of: ",") {
                        let encodedString = responseStr[responseStr.index(after: commaIndex)...]
                        
                        if Data(base64Encoded: String(encodedString), options: .ignoreUnknownCharacters) != nil {
                            
                            let keyData: Data = BLEEncryption.hexToBytes(SpectraBLE.shared.encryptionKey)
                                
                                    let resultData = BLEEncryption.AES128Decrypt(keyData)
                                    
                                    var randomBBytes = [UInt8](repeating: 0, count: 32)
                                    resultData.copyBytes(to: &randomBBytes, count: 32)
                                    
                                    let randomAData = BLEEncryption().getRandomA()
                                    var randomAInBytes = [UInt8](repeating: 0, count: 8)
                                    randomAData?.copyBytes(to: &randomAInBytes, count: 8)
                                    
                                    var randomBytes = [UInt8](repeating: 0, count: 16)
                                    randomBytes[0...3] = randomAInBytes[0...3]
                                    randomBytes[4...7] = randomBBytes[11...14]
                                    randomBytes[8...11] = randomAInBytes[4...7]
                                    randomBytes[12...15] = randomBBytes[15...18]

                                    let newSecureKeyHexStr = randomBytes.map { String(format: "%02X", $0) }.joined()

                                    let randomBytesData = Data(randomBytes)
                                    let securePunchCommand = BLEEncryption.getSecurePunchCommand(keyData: randomBytesData)
                                    
                                    print("Secure Punch Command: \(securePunchCommand)")
                                    
                                    peripheral.writeValue(securePunchCommand.data(using: .ascii) ?? Data(),
                                                         for: characteristic,
                                                         type: .withResponse)
                                    
                                    isSecureCommandDone = true
                                }
                            }
                        }
                    }
             else {
                isSecureCommandDone = false
                
                 if Data(base64Encoded: data, options: .ignoreUnknownCharacters) != nil {
                    
                     let keyData: Data = BLEEncryption.hexToBytes(SpectraBLE.shared.encryptionKey)
                        
                    let resultData = BLEEncryption.AES128Decrypt(keyData)
                        let resultBytes = [UInt8](resultData)
                        
                        if resultBytes.count > 7 {
                            DispatchQueue.main.async {
                                if resultBytes[7] == 1 {
                                    // UIApplication.shared.topMostController()?.view.makeToast(CCommandSuccessMsg, duration: 2.0, position: .bottom)
                                } else {
                                    // UIApplication.shared.topMostController()?.view.makeToast(Functions.getBLEResponseFailureMessage(resultBytes[7]), duration: 2.0, position: .bottom)
                                }
                            }
                    }
                }
            }
        }
    }

    
    
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    }
}

//// MARK: - BLE Peripheral Delegate Methods
//
//extension SpectraBLE: CBPeripheralDelegate {
//    
//    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//        
//        if let error = error {
//            print("\n❌ Error discovering services: \(error.localizedDescription)\n")
//            handleFailedPunch(peripheral)
//            return
//        }
//        
//        if let services = peripheral.services {
//            for service in services {
//                if let connectedDevice = connectedDevice, connectedDevice.IsXPReader {
//                    peripheral.discoverCharacteristics([
//                        CBUUID(string: DeviceConstant.CCharacteristicUuidXPReader),
//                        CBUUID(string: DeviceConstant.CCharacteristicUuidForResponseXPReader)
//                    ], for: service)
//                } else {
//                    peripheral.discoverCharacteristics([
//                        CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse),
//                        CBUUID(string: DeviceConstant.CCharacteristicUuid)
//                    ], for: service)
//                }
//            }
//        }
//    }
//    
//    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//        
//        if let error = error {
//            print("\n❌ Error discovering characteristics: \(error.localizedDescription)\n")
//            handleFailedPunch(peripheral)
//            return
//        }
//        
//        guard let characteristics = service.characteristics else {
//            handleFailedPunch(peripheral)
//            return
//        }
//        
//        for characteristic in characteristics {
//            if let connectedDevice = connectedDevice, connectedDevice.IsXPReader {
//                
//                if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidXPReader) {
//                    peripheral.setNotifyValue(true, for: characteristic)
//                    isConnect ? sendCommandOnDevice(characteristic: characteristic, peripheral: peripheral) : disconnect()
//                    
//                } else if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponseXPReader) {
//                    peripheral.setNotifyValue(true, for: characteristic)
//                    peripheral.readValue(for: characteristic)
//                }
//                
//            } else {
//                
//                if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuid) {
//                    peripheral.setNotifyValue(true, for: characteristic)
//                    
//                    if isConnect {
//                        if let foundDevice = scannedDevices.first(where: { $0.peripheralId == peripheral.identifier.uuidString }),
//                           foundDevice.isSecureDevice {
//                            print("🔒 Performing Secure Punch...")
//                            performSecurePunch(peripheral: peripheral, characteristic: characteristic)
//                        } else {
//                            sendCommandOnDevice(characteristic: characteristic, peripheral: peripheral)
//                        }
//                    } else {
//                        disconnect()
//                    }
//                    
//                } else if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse) {
//                    peripheral.setNotifyValue(true, for: characteristic)
//                    peripheral.readValue(for: characteristic)
//                }
//            }
//        }
//    }
//    
//    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
//        
//        if let error = error {
//            print("❌ Error writing characteristic: \(error.localizedDescription)")
//            handleFailedPunch(peripheral)
//            return
//        }
//        
//        handleSuccessfulPunch(peripheral)
//    }
//    
//    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        
//        if let error = error {
//            print("❌ Error updating characteristic: \(error.localizedDescription)")
//            handleFailedPunch(peripheral)
//            return
//        }
//        
//        guard let characteristicValue = characteristic.value else {
//            print("⚠️ Characteristic value is nil")
//            return
//        }
//        
//        if characteristic.uuid == CBUUID(string: DeviceConstant.CCharacteristicUuidForResponse) {
//            
//            let periId = peripheral.identifier.uuidString
//            if let foundDevice = scannedDevices.first(where: { $0.peripheralId == periId }),
//               foundDevice.isSecureDevice {
//                
//                print("🔐 Secure Device Found. Processing Response...")
//                processSecureResponse(peripheral, characteristic: characteristic, data: characteristicValue)
//                
//            } else {
//                print("⚡ Normal Device. Processing Response...")
//                processNormalResponse(peripheral, characteristic: characteristic, data: characteristicValue)
//            }
//        }
//    }
//    
//    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
//        if let error = error {
//            print("❌ Error updating notification state: \(error.localizedDescription)")
//        }
//    }
//}
//
//// MARK: - Secure Punch Handling
//
//private extension SpectraBLE {
//    
//    func performSecurePunch(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
//        
//        let encryptionKey = SpectraBLE.shared.encryptionKey // Direct assignment since it's not optional
//        
//        if encryptionKey.isEmpty {
//            print("❌ Encryption key is missing or empty!")
//            return
//        }
//        
//        let keyData = BLEEncryption.hexToBytes(encryptionKey)
//        let securePunchCommand = BLEEncryption.getSecurePunchCommand(keyData: keyData)
//        
//        print("🔐 Sending Secure Punch Command: \(securePunchCommand)")
//        
//        
//        print("Characteristic \(characteristic.uuid) properties: \(characteristic.properties)")
//
//        if characteristic.properties.contains(.notify) {
//            peripheral.setNotifyValue(true, for: characteristic)
//        } else {
//            print("⚠️ Notifications NOT supported for characteristic:", characteristic.uuid)
//        }
//
//        if characteristic.properties.contains(.read) {
//            peripheral.readValue(for: characteristic)
//        } else {
//            print("⚠️ Reading NOT permitted for characteristic:", characteristic.uuid)
//        }
//        
//        peripheral.writeValue(securePunchCommand.data(using: .ascii) ?? Data(),
//                              for: characteristic,
//                              type: .withResponse)
//        
//        isSecureCommandDone = true
//    }
//    
//    func processSecureResponse(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {
//        
//        guard let responseStr = String(data: data, encoding: .utf8),
//              let commaIndex = responseStr.firstIndex(of: ",") else {
//            print("⚠️ Secure Punch Response is Invalid")
//            return
//        }
//        
//        let encodedString = responseStr[responseStr.index(after: commaIndex)...]
//        
//        if let decodedData = Data(base64Encoded: String(encodedString), options: .ignoreUnknownCharacters) {
//            
//            let keyData = BLEEncryption.hexToBytes(SpectraBLE.shared.encryptionKey)
//            let resultData = BLEEncryption.AES128Decrypt(keyData)
//            
//            var randomBytes = [UInt8](repeating: 0, count: 16)
//            resultData.copyBytes(to: &randomBytes, count: 16)
//            
//            let securePunchCommand = BLEEncryption.getSecurePunchCommand(keyData: Data(randomBytes))
//            
//            print("🔐 Secure Punch Command: \(securePunchCommand)")
//            
//            peripheral.writeValue(securePunchCommand.data(using: .ascii) ?? Data(),
//                                  for: characteristic,
//                                  type: .withResponse)
//            
//            isSecureCommandDone = true
//        }
//    }
//    
//    func processNormalResponse(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {
//        
//        if let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) {
//            
//            let keyData = BLEEncryption.hexToBytes(SpectraBLE.shared.encryptionKey)
//            let resultData = BLEEncryption.AES128Decrypt(keyData)
//            
//            let resultBytes = [UInt8](resultData)
//            
//            if resultBytes.count > 7 {
//                DispatchQueue.main.async {
//                    if resultBytes[7] == 1 {
//                        print("✅ Normal Punch Success!")
//                    } else {
//                        print("❌ Normal Punch Failed!")
//                    }
//                }
//            }
//        }
//    }
//    
//    func handleSuccessfulPunch(_ peripheral: CBPeripheral) {
//        let periId = peripheral.identifier.uuidString
//        if let device = scannedDevices.currentDevice(forPeripheralId: periId) {
//            device.wasPunched = false
//            scannedDevices.updateDevice(device)
//        }
//        
//        isConnectionOngoing = false
//        if peripheral.state == .connected {
//            disconnect()
//        }
//    }
//    
//    func handleFailedPunch(_ peripheral: CBPeripheral) {
//        let periId = peripheral.identifier.uuidString
//        if let device = scannedDevices.currentDevice(forPeripheralId: periId) {
//            device.wasPunched = false
//            scannedDevices.updateDevice(device)
//        }
//    }
//}

//MARK: - BLE peripheral manager delegate methods
//MARK: -
extension SpectraBLE: CBPeripheralManagerDelegate {
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    }
}

extension [String : Any] {
    
    func isBOITDevice() -> Bool {
        
        guard let addvertData = self["kCBAdvDataManufacturerData"] as? NSData else {
            return false
        }
        let array: [UInt8] = Array(addvertData)
        if array.indices.contains(5)
        {
            let fifthElement = Int(array[5])
            if fifthElement == 6 || fifthElement == 2 // 6 & 2 = BIOT DEVICES
            {
                return true
            }
            else
            {
                return false
            }
        } else {
            return false
        }
    }
    
    func getDeviceType() -> Int {
        
        guard let addvertData = self["kCBAdvDataManufacturerData"] as? NSData else {
            return -1
        }
        let array: [UInt8] = Array(addvertData)
        
        
        if array.indices.contains(5)
        {
            let fifthElement = Int(array[5])
            return fifthElement
        }
        else
        {
            return -1
        }
    }
    
    func isSecureDevice() -> Bool {
        
        guard let addvertData = self["kCBAdvDataManufacturerData"] as? NSData else {
            return false
        }
        
        let bytes = [UInt8](addvertData)
        let length = bytes.count

        if length > 5 {
            let type = bytes[3]
            let valueToCheck = bytes[6]
            let bitwiseAndOfValue = valueToCheck & 0x02

            return bitwiseAndOfValue == 0x02
        }
        
        return false
    }

}


