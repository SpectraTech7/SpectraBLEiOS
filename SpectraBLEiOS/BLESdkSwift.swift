//
//  BLESdkSwift.swift
//  BleSdkSwift
//
//  Created by Manoj on 29/01/22.
//

import CoreBluetooth

extension String {
    func remove() {
        UserDefaults.standard.removeObject(forKey: "com.spectra.blesdk.encryptionKey")
        UserDefaults.standard.synchronize()
    }
}

@objc
public class SpectraBLE: NSObject {
    
    public static let shared = SpectraBLE()
    
    override private init() {
        super.init()
    }
    
    @objc public weak var bleManagerDelegate: BleManagerDelegate?
    
    var deviceRemoveTimer: Timer?
    var command: Command?
    var connectedDevice: BLEDevice?
    var peripheralManager = CBPeripheralManager()
    var deviceListTimer: Timer?
    var globalCallback: ((BLEEvent, Any) -> Void)?
    var sdkVersion = "V 1.0"
    var hasStartedScan = false // Track if scanning is already started
    var isSecureCommandDone:Bool = false
    
    
    //TODO: Tap and go parameters
    var isTapAndGoEnabled: Bool = true
    var tagId: String = ""
    var tapAndGoSelectedFloor: Int = 0
    var tapAndGoBoardingFloor: Int = 0
    var tapAndGoDestinationFloor: Int = 0
    var isConnect:Bool = false
    
    var lastLoggedRSSIArray: [Int] = []
    var lastLoggedDecisionArray: [Int] = []
    var hasVibrated = false  // Add this as a class-level variable

    
    var currentPunchedDeviceId: String? // The last punched device
    var currentPunchedRSSI: Int?        // RSSI of the last punched device
    let rssiStabilityMargin = 5 // Avoid repunching due to small RSSI changes
    
    var sensitityLevel: Int = 2 // 1 > Low,  2 > Medium, 3 > High
    var lastTapTime: Double = Date().timeIntervalSince1970
    var connectTime: Double = Date().timeIntervalSince1970
    
    public var RSSIs: [Int] = []        // Array to store RSSI values
    public let RSSILength = 20   
    public let DecisionArrayLength = 7       // Length of RSSI window
    public let DecisionArray:[Int] = [0,0,0,0,0,0,0]
    var medianRSSI: Int = -99           // Default value when not enough packets
       
    var encryptionKey: String {
        get {
            return UserDefaults.standard.value(forKey: "com.spectra.blesdk.encryptionKey") as? String ?? ""
        } set {
            UserDefaults.standard.set(newValue, forKey: "com.spectra.blesdk.encryptionKey")
        }
    }
    //@objc public var scannedDevices: NSMutableArray = [BLEDevice]() as! NSMutableArray
    
    public var scannedDevices = [BLEDevice]() 
    public var lScannedDevices = [BLEDevice]()
    
    var isConnectionOngoing: Bool = false
    
    lazy var centralManager: CBCentralManager? = nil
    
    // Create an operation queue for BLE processing
    let bleProcessingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5  // Adjust concurrency as needed
        return queue
    }()
    
    // Separate queues for different processes
     let scanQueue = DispatchQueue(label: "com.spectra.scanQueue", qos: .background)
     let processQueue = OperationQueue() // Handles discovered devices
     let punchQueue = DispatchQueue(label: "com.spectra.punchQueue", qos: .userInitiated)
     let removeDeviceQueue = DispatchQueue(label: "com.spectra.removeDeviceQueue", qos: .background)

}

extension Array where Element == BLEDevice {
    func currentDevice(forPeripheralId id: String) -> BLEDevice? {
        return self.first(where: { $0.peripheralId == id })
    }
    
    mutating func updateDevice(_ newDevice: BLEDevice) {
        if let index = self.firstIndex(where: { $0.peripheralId == newDevice.peripheralId }) {
            self[index] = newDevice
        }
    }
}

class BLETapAndGodDefaultValue {
    
    static let shared = BLETapAndGodDefaultValue()
    private init() {}
    
    var tagId: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "com.spectra.ble.tagId")
        }
        get {
            return UserDefaults.standard.string(forKey: "com.spectra.ble.tagId") ?? ""
        }
    }
    
    var sensitivity: Int {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "com.spectra.ble.sensitivity")
        } get {
            return UserDefaults.standard.integer(forKey: "com.spectra.ble.sensitivity")
        }
    }
    
    var tapAndGoSelectedFloor: Int {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "com.spectra.ble.selectedFloor")
        } get {
            return UserDefaults.standard.integer(forKey: "com.spectra.ble.selectedFloor")
        }
    }
    var tapAndGoBoardingFloor: Int {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "com.spectra.ble.BoardingFloor")
        } get {
            return UserDefaults.standard.integer(forKey: "com.spectra.ble.BoardingFloor")
        }
    }
    
    var tapAndGoDestinationFloor: Int {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "com.spectra.ble.DestinationFloor")
        } get {
            return UserDefaults.standard.integer(forKey: "com.spectra.ble.DestinationFloor")
        }
    }
    
    var isAllowedPunch: Int {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "com.spectra.ble.shouldAllowPunch")
        } get {
            return UserDefaults.standard.integer(forKey: "com.spectra.ble.shouldAllowPunch")
        }
    }
    
    func removeAllStoreProperties() {
        UserDefaults.standard.removeObject(forKey: "com.spectra.ble.DestinationFloor")
        UserDefaults.standard.removeObject(forKey: "com.spectra.ble.BoardingFloor")
        UserDefaults.standard.removeObject(forKey: "com.spectra.ble.selectedFloor")
        UserDefaults.standard.removeObject(forKey: "com.spectra.ble.sensitivity")
        UserDefaults.standard.removeObject(forKey: "com.spectra.ble.shouldAllowPunch")
    }
}
