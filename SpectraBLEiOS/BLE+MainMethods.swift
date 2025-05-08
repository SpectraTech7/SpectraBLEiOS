//
//

import Foundation
import CoreBluetooth
import CoreLocation

//MARK: -
//MARK: - Main Methods

extension SpectraBLE {

    
    //TODO: STOP SCANNING CALL
    @objc
    public func stopScan() {
        self.centralManager?.stopScan()
        self.centralManager = nil
        self.scannedDevices.removeAll()
        
        tagId = ""
        tapAndGoSelectedFloor = 0
        tapAndGoBoardingFloor = 0
        tapAndGoDestinationFloor = 0
    }
    
    //TODO: INSERT TAP AND GO DATA
    @objc
    public func insertTapAndGoData(tag: String,
                                   destinationFloor: Int,
                                   boardingFloor: Int,
                                   selectedFloor: Int,
                                   sensitivity: Int) {
        
        if !BLETapAndGodDefaultValue.shared.tagId.isNumeric {
            return
        }
        
        sensitityLevel = sensitivity
        tagId = BLETapAndGodDefaultValue.shared.tagId
        tapAndGoSelectedFloor = BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor
        tapAndGoBoardingFloor = BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor
        tapAndGoDestinationFloor = BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor
        sensitityLevel = BLETapAndGodDefaultValue.shared.sensitivity
        
    }
    
    //TODO: MAKE PUNCH CALL
    public func makePunch(tagId: String,
                          destinationFloor: Int,
                          boardingFloor: Int,
                          selectedFloor: Int,
                          deviceUniqueId: String) {
        
        //Check for tag is numeric or other.. if other then return from here with error messsage
        punchQueue.async {
            
//            if !tagId.isNumeric || tagId == "" {
//                DispatchQueue.main.async {
//                    self.bleManagerDelegate?.onBleManagerFailure(error: BLEErrorDesc.tagMustBeNumeric)
//                }
//                return
//            }
            
            var key = SpectraBLE.shared.encryptionKey
            if key == "" {
                if let _key = KeychainHelper.shared.value(forKey: DeviceConstant.CEncryptionKey) {
                    key = _key
                    SpectraBLE.shared.encryptionKey = _key
                } else {
                    return
                }
            }
            
            if self.centralManager == nil {
             
                return
            }
            
            if self.scannedDevices.count == 0 {
                return
            }
            
            var isIdEntered = false
            if deviceUniqueId.isEmpty {
                
                let arrSorted = self.scannedDevices.sorted { device1, device2 in
                    let threshold1 = Double(self.getEntryThreshold(device: device1)) // Convert to Double
                    let threshold2 = Double(self.getEntryThreshold(device: device2)) // Convert to Double
                    
                    let thresholdDiff1 = abs((device1.estimateDistance ?? 0.0) - threshold1)
                    let thresholdDiff2 = abs((device2.estimateDistance ?? 0.0) - threshold2)
                    
                    return thresholdDiff1 < thresholdDiff2
                }
                
                if arrSorted.count == 0 {
                    return
                }
                
               if let _foundDevice = arrSorted.currentDevice(forPeripheralId: self.currentPunchedDeviceId ?? "")
                {
                   self.connectedDevice = _foundDevice
               }
                else{
                    self.connectedDevice = arrSorted[0]
                }
                
            } else {
                
                isIdEntered = true
                
                let index = self.scannedDevices.firstIndex { device in
                    return device.peripheralId == deviceUniqueId
                }
                
                if index != nil {
                    
                    if self.scannedDevices.count > index! {
                        self.connectedDevice = self.scannedDevices[index!]
                    }
                }
            }
            
            guard let `peripheralID` = self.connectedDevice?.peripheralId else {
                
                if isIdEntered {
                } else {
                  
                }
                
                return
            }
            
            let currentTimestamp = Date().timeIntervalSince1970
            let lastPunchDeviceId = UserDefaults.standard.string(forKey: "LastPunchDeviceId")
            let lastPunchReaderId = UserDefaults.standard.string(forKey: "LastPunchReaderId")
            let lastPunchTimestamp = UserDefaults.standard.object(forKey: "LastPunchTimestamp") as? Double ?? 0.0

               
            if lastPunchDeviceId == self.connectedDevice?.peripheralId &&
               lastPunchReaderId == tagId &&
               (currentTimestamp - lastPunchTimestamp) < 2 {
               
               UserDefaults.standard.setValue(currentTimestamp, forKey: "LastPunchTimestamp")
               UserDefaults.standard.synchronize()
               
               return
           }
            UserDefaults.standard.setValue(self.connectedDevice?.peripheralId, forKey: "LastPunchDeviceId")
            UserDefaults.standard.setValue(tagId, forKey: "LastPunchReaderId")
            UserDefaults.standard.setValue(currentTimestamp, forKey: "LastPunchTimestamp")
            UserDefaults.standard.synchronize()
            
            
            self.connectedDevice?.isOutofRange = false
            self.connectedDevice?.wasPunched = true
            self.connectedDevice?.punchTimeStamp = Date().timeIntervalSince1970
            self.scannedDevices.updateDevice(self.connectedDevice!)
            
            BLEEncryption.setEncryptionKey(key)
            BLEEncryption.setPeripheralId(peripheralID)
            BLEEncryption.setTagId(tagId)
            BLEEncryption.setDestinationFloor("\(destinationFloor)")
            BLEEncryption.setBoardingFloor("\(boardingFloor)")
            BLEEncryption.setSelectedFloor("\(selectedFloor)")
            BLEEncryption.setDeviceType(self.connectedDevice?.deviceType ?? "")
            
            if let manufData = self.connectedDevice?.manufactureData {
                BLEEncryption.setDeviceData(manufData)
            }
            
            self.command = .punch
            
            guard let `peripheralToConnect` = self.connectedDevice?.peripheral else {
                return
            }
        
            let options: [String: Any] = [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                CBConnectPeripheralOptionNotifyOnNotificationKey: true
            ]
            
            
            // Convert timestamp to Date
            let date = Date(timeIntervalSince1970: currentTimestamp)

            // Create DateFormatter to format the date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium  // Uses system date format
            formatter.timeStyle = .medium  // Uses system time format
            formatter.locale = Locale.current // Adapts to device settings

            // Convert Date to formatted string
            let formattedDate = formatter.string(from: date)
            
            
            var arrDevices = [DeviceData]()
            
            
            var strDeviceName = ""
            
            if let inOut = self.connectedDevice?.inOutFlag?.uppercased()
            {
                if inOut == "49"
                {
                    strDeviceName = (self.connectedDevice?.deviceName ?? "") + " - IN"
                }
                else if inOut == "4F"
                {
                    strDeviceName = (self.connectedDevice?.deviceName ?? "") + " - OUT"
                }
                else{
                    strDeviceName = (self.connectedDevice?.deviceName ?? "")
                }
            }
            
        
            let data:DeviceData = DeviceData(deviceName: strDeviceName, deviceType: self.connectedDevice?.deviceType ?? "", deviceID: self.connectedDevice?.peripheralId ?? "", punchTime: formattedDate)
                
            arrDevices.append(data)
                

            if let callback = self.globalCallback {
                callback(.SUCCESS, BLEData(code: 200, message: BLENewMessages.punchSuccessFully, data: arrDevices, sdkVersion: self.sdkVersion))
            }
            
            self.centralManager?.connect(peripheralToConnect, options: options)
        }
    }
    
    
    // MARK: - Start Timer to Fetch Device List Every 1 Second
    private func startDeviceListTimer(callback: @escaping (BLEEvent, Any) -> Void) {
        // Invalidate any existing timer before starting a new one
        deviceListTimer?.invalidate()

        // Create a repeating timer that calls getDeviceList every 1 second
        deviceListTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.getDeviceList(callback: callback)
        }
    }

    // MARK: - Stop Timer
    public func stopDeviceListTimer() {
        deviceListTimer?.invalidate()
        deviceListTimer = nil
    }
    
    
    //TODO: GET SDK VERSION
    @objc
    public func getSdkVersion() {
        bleManagerDelegate?.onBleManagerSuccess(successMsg: "1.0")
    }
    
    
    //TODO: REMOVE KEY CHAIN VALUE
    @objc
    public func removeKeychain() {
        if KeychainHelper.shared.value(forKey: DeviceConstant.CEncryptionKey) != nil {
            KeychainHelper.shared.removeValue(forKey: DeviceConstant.CEncryptionKey)
            return
        }
    }
    
    private func requestBluetoothPermission() {
            print("Requesting Bluetooth permission...")
            self.centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    
    //TODO: Latest Method Called
    public func initialize(
        encryptionKey: String,
        bleTag: String,
        punchRange: Int,
        additionalInfo: String? = nil, // Optional parameter
        callback: @escaping (BLEEvent, Any) -> Void
    ) {
        
        globalCallback = callback
        
        // Check Bluetooth authorization status
        let bluetoothStatus = CBCentralManager.authorization
        
        if bluetoothStatus == .denied || bluetoothStatus == .restricted {
            callback(.ERROR, BLEData(code: BLEErrorDesc.enableBluetooth.errorCode, message: BLEErrorDesc.enableBluetooth.errorMessage))
            return
        }
        
        // If status is not determined, request permission
        if bluetoothStatus == .notDetermined {
            requestBluetoothPermission()
            return
        }
               
        
        var finalAdditionalInfo = additionalInfo ?? "" // Use provided value or leave blank

        if let additionalInfo = additionalInfo, let validationError = validateAdditionalInfo(additionalInfo) {
            callback(.ERROR, validationError)
            
            BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor = 0
            BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor = 0
            BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor = 0
            
            return
        }

        if let additionalInfo = additionalInfo,
           let jsonData = additionalInfo.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
           let fields = jsonObject["fields"] as? [[String: Any]] {

            for field in fields {
                if let key = field["key"] as? String, let value = field["value"] as? Int {
                    switch key {
                    case "DestinationFloor":
                        BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor = value
                    case "BoardingFloor":
                        BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor = value
                    case "SelectedFloor":
                        BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor = value
                    default:
                        break
                    }
                }
            }
        } else {
            BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor = 0
            BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor = 0
            BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor = 0
        }

        BLETapAndGodDefaultValue.shared.tagId = bleTag
        BLETapAndGodDefaultValue.shared.sensitivity = punchRange
        
        self.tagId = BLETapAndGodDefaultValue.shared.tagId
        self.tapAndGoBoardingFloor = BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor
        self.tapAndGoSelectedFloor = BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor
        self.tapAndGoDestinationFloor = BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor
        self.sensitityLevel = BLETapAndGodDefaultValue.shared.sensitivity
        
        SpectraBLE.shared.encryptionKey = encryptionKey
        KeychainHelper.shared.setValue(encryptionKey, forKey: DeviceConstant.CEncryptionKey)
        
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            self.startScan(callback: callback)
            
        }
    }
    
    
    private func validateAdditionalInfo(_ jsonString: String) -> BLEData? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return BLEData(code: BLEErrorDesc.invalidAdditionalInfo.errorCode, message:BLEErrorDesc.invalidAdditionalInfo.errorMessage)
        }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                
                guard let noOfFields = jsonObject["no_of_fields"] as? Int else {
                    return BLEData(code: BLEErrorDesc.noOfFiledMustBeInInteger.errorCode, message: BLEErrorDesc.noOfFiledMustBeInInteger.errorMessage)
                }
                
                guard let fields = jsonObject["fields"] as? [[String: Any]], fields.count == noOfFields else {
                    return BLEData(code: BLEErrorDesc.fieldMustBeValidJson.errorCode, message: BLEErrorDesc.noOfFiledMustBeInInteger.errorMessage)
                }
                
                for field in fields {
                    guard let _ = field["length"] as? Int else {
                        return BLEData(code: BLEErrorDesc.lengthMustBeInInteger.errorCode, message: BLEErrorDesc.lengthMustBeInInteger.errorMessage)
                    }
                    
                    guard let key = field["key"] as? String, !key.isEmpty else {
                        return BLEData(code: BLEErrorDesc.keyMustBeNonEmpty.errorCode, message: BLEErrorDesc.keyMustBeNonEmpty.errorMessage)
                    }
                }
            
                return nil
                
            } else {
                return BLEData(code: BLEErrorDesc.invalidAdditionalInfo.errorCode, message:BLEErrorDesc.invalidAdditionalInfo.errorMessage)
            }
        } catch {
            return BLEData(code: BLEErrorDesc.invalidAdditionalInfo.errorCode, message:BLEErrorDesc.invalidAdditionalInfo.errorMessage)
        }
    }
    
    // TODO: START SCANNING CALL
    public func startScan(callback: @escaping (BLEEvent, Any) -> Void) {
        self.tagId = BLETapAndGodDefaultValue.shared.tagId
        self.tapAndGoBoardingFloor = BLETapAndGodDefaultValue.shared.tapAndGoBoardingFloor
        self.tapAndGoSelectedFloor = BLETapAndGodDefaultValue.shared.tapAndGoSelectedFloor
        self.tapAndGoDestinationFloor = BLETapAndGodDefaultValue.shared.tapAndGoDestinationFloor
        self.sensitityLevel = BLETapAndGodDefaultValue.shared.sensitivity
        
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.centralManager == nil {
                self.centralManager = CBCentralManager(delegate: self,
                                                       queue: nil,
                                                       options: [
                                                        CBCentralManagerScanOptionAllowDuplicatesKey: false,
                                                        CBCentralManagerOptionShowPowerAlertKey: false
                                                       ])
            }
            
            if self.error != nil {
                return
            }
                    
            self.centralManager?.scanForPeripherals(
                withServices: [CBUUID(string: DeviceConstant.CDeviceUDID)],
                options: [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [CBUUID(string: DeviceConstant.CDeviceUDID)], CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
           
            DispatchQueue.main.async {
                
                if !self.hasStartedScan { // ✅ Only call startScan if not already started
                    self.hasStartedScan = true
                    callback(.SUCCESS, BLEData(code: 100, message: BLENewMessages.initializeSuccessFully, data: nil, sdkVersion: self.sdkVersion))
                }
                
                self.startDeviceListTimer(callback: callback)
                
            }
        }
    }
    
    //TODO: GET DEVICE LIST CALL
    public func getDeviceList(callback: @escaping (BLEEvent, Any) -> Void) {
        
        if centralManager == nil {
            return
        }
        
        var arrDevices = [DeviceData]()
        
        for device in scannedDevices {
            
            var strDeviceName = ""
            
            if let inOut = device.inOutFlag?.uppercased()
            {
                if inOut == "49"
                {
                    strDeviceName = (device.deviceName ?? "") + " - IN"
                }
                else if inOut == "4F"
                {
                    strDeviceName = (device.deviceName ?? "") + " - OUT"
                }
                else{
                    strDeviceName = (device.deviceName ?? "")
                }
            }
            
            let data:DeviceData = DeviceData(deviceName: strDeviceName, deviceType: (device.deviceType ?? ""), deviceID: (device.peripheralId ?? ""), punchTime: "")
            arrDevices.append(data)
        }
        
        if arrDevices.count > 0 {
            callback(.DEVICE_LIST, BLEData(code: 200, message: BLENewMessages.deviceGetSuccessFully, data: arrDevices, sdkVersion: sdkVersion))
        } else {
            callback(.DEVICE_LIST,BLEData(code: 200, message: BLENewMessages.noDeviceFound, data: arrDevices, sdkVersion: sdkVersion))
        }
    }
}



extension SpectraBLE {
    
    internal func getEntryThreshold(device: BLEDevice) -> Int {
        
        switch sensitityLevel {
            
            //Low
        case 1:
            
            if device.getDeviceType() == DeviceType.XP_PLUS.rawValue ||  device.getDeviceType() == DeviceType.XP_READER_NEW_MTU.rawValue || device.getDeviceType() == DeviceType.XP_PRO_HID.rawValue || device.getDeviceType() == DeviceType.XP_PRO_SPECTRA.rawValue
            {
                return -50
            }
            else if device.getDeviceType() == DeviceType.BST3S.rawValue || device.getDeviceType() == DeviceType.BSC3S.rawValue || device.getDeviceType() == DeviceType.UST3S.rawValue
            {
                return -38
            }
            else if  device.getDeviceType() == DeviceType.XP_READER_OLD.rawValue
            {
                return -70
            }
            else if  device.getDeviceType() == DeviceType.BIOT_OLD.rawValue
            {
                return -45
            }
            
            //Medium
        case 2:
            if device.getDeviceType() == DeviceType.XP_PLUS.rawValue ||  device.getDeviceType() == DeviceType.XP_READER_NEW_MTU.rawValue || device.getDeviceType() == DeviceType.XP_PRO_HID.rawValue || device.getDeviceType() == DeviceType.XP_PRO_SPECTRA.rawValue
            {
                return -56
            }
            else if device.getDeviceType() == DeviceType.BST3S.rawValue || device.getDeviceType() == DeviceType.BSC3S.rawValue || device.getDeviceType() == DeviceType.UST3S.rawValue
            {
                return -43
            }
            else if  device.getDeviceType() == DeviceType.XP_READER_OLD.rawValue
            {
                return -76
            }
            else if  device.getDeviceType() == DeviceType.BIOT_OLD.rawValue
            {
                return -51
            }
            
            //High
        case 3:
            
            if device.getDeviceType() == DeviceType.XP_PLUS.rawValue || device.getDeviceType() == DeviceType.XP_READER_NEW_MTU.rawValue || device.getDeviceType() == DeviceType.XP_PRO_HID.rawValue || device.getDeviceType() == DeviceType.XP_PRO_SPECTRA.rawValue
            {
                return -63
            }
            else if device.getDeviceType() == DeviceType.BST3S.rawValue || device.getDeviceType() == DeviceType.BSC3S.rawValue || device.getDeviceType() == DeviceType.UST3S.rawValue
            {
                return -53
            }
            else if  device.getDeviceType() == DeviceType.XP_READER_OLD.rawValue
            {
                return -81
            }
            else if  device.getDeviceType() == DeviceType.BIOT_OLD.rawValue
            {
                return -45
            }
            
        default:
            return -63
        }
        
        return -63
    }
    
    func getSmoothedRssi(_ rssiArray: [Int]) -> Int {
        // Step 0: Sanitize input (filter out 0 or invalid RSSI values)
        let validRssi = rssiArray.filter { $0 < 0 }
        guard !validRssi.isEmpty else { return -99 }

        let maxChange = 4 // Maximum allowed RSSI jump
        var filteredRssi = [validRssi.first!]

        // Step 1: Filter out sudden jumps
        for i in 1..<validRssi.count {
            let prev = filteredRssi.last!
            let curr = validRssi[i]
            if abs(curr - prev) <= maxChange {
                filteredRssi.append(curr)
            }
        }

        // Step 2: If too many values were removed, fallback to first few valid entries
        if filteredRssi.count < 3 {
            filteredRssi = Array(validRssi.prefix(min(5, validRssi.count)))
        }

        // Step 3: Weighted Moving Average
        let weights = [0.1, 0.2, 0.3, 0.4] // Modify if using more data
        let recentRssi = Array(filteredRssi.suffix(weights.count))
        let actualWeights = Array(weights.suffix(recentRssi.count))
        let weightSum = actualWeights.reduce(0, +)

        let weightedAvg = zip(recentRssi, actualWeights).reduce(0.0) { acc, pair in
            acc + Double(pair.0) * pair.1
        } / weightSum

        // Step 4: Exponential Smoothing (optional)
        var smoothed = weightedAvg
        for rssi in filteredRssi.dropFirst() {
            let alpha = abs(Double(rssi) - smoothed) > Double(maxChange) ? 0.5 : 0.2
            smoothed = alpha * Double(rssi) + (1 - alpha) * smoothed
        }

        return Int(round(smoothed))
    }
}

