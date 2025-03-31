
import Foundation

@objc
public protocol BleManagerDelegate {
    
    func onInitSuccess(SuccessMsg: String)
    func onInitFailure(error: BleSdkError)
    
    func onScanSuccess(successMsg: String)
    func onScanFailure(error: BleSdkError)
    
    func onBleManagerSuccess(successMsg: String)
    func onBleManagerFailure(error: BleSdkError)
    
    func onCommandSendSuccess(successMsg: String)
    
    func onGetDeviceListSuccess(successMsg: String, deviceArray: [[String: Any]])
    func onGetDeviceListFailure(error: BleSdkError)
}
