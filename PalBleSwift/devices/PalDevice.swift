//
//  PalDevice.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth

enum PalDeviceCharacteristic: String, CharacteristicIdentifier {
    case dfu =          "46e70001-f545-430c-b11f-54697f3103f4"
    
    case setup =        "46e73001-f545-430c-b11f-54697f3103f4"
    
    case info =         "46e73101-f545-430c-b11f-54697f3103f4"
    case time =         "46e73102-f545-430c-b11f-54697f3103f4"
    case encryption =   "46e73103-f545-430c-b11f-54697f3103f4"
    case data =         "46e73104-f545-430c-b11f-54697f3103f4"
    case challenge =    "46e73105-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    //Service to which characteristic belongs
    var service: ServiceIdentifier {
        switch self {
        case .dfu:
            return PalDeviceService.dfu
        case .setup:
            return PalDeviceService.setup
        case .info, .time, .encryption, .data, .challenge:
            return DeviceService.common
        }
    }
}

enum PalDeviceService: String, ServiceIdentifier {
    case dfu =      "46e70000-f545-430c-b11f-54697f3103f4"
    case setup =    "46e73000-f545-430c-b11f-54697f3103f4"
    case common =   "46e73100-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

@objc public class PalDevice : NSObject {
    var bleDevice: Peripheral!
    
    private static let P8C_DFU_CHARACTERISTIC_UUID = UUID.init(uuidString: "46e70001-f545-430c-b11f-54697f3103f4")

    static let P8C_SETUP_CHARACTERISTIC_UUID =       UUID.init(uuidString: "46e73001-f545-430c-b11f-54697f3103f4")!

    static let P8C_INFO_CHARACTERISTIC_UUID =        UUID.init(uuidString: "46e73101-f545-430c-b11f-54697f3103f4")
    static let P8C_TIME_CHARACTERISTIC_UUID =        UUID.init(uuidString: "46e73102-f545-430c-b11f-54697f3103f4")
    static let P8C_ENCRYPTION_CHARACTERISTIC_UUID =  UUID.init(uuidString: "46e73103-f545-430c-b11f-54697f3103f4")
    static let P8C_DATA_CHARACTERISTIC_UUID =        UUID.init(uuidString: "46e73104-f545-430c-b11f-54697f3103f4")
    static let P8C_CHALLENGE_CHARACTERISTIC_UUID =   UUID.init(uuidString: "46e73105-f545-430c-b11f-54697f3103f4")

    static let RECONNECTION_ATTEMPTS = 3
    
    var serial: String?
    //var mode: Int?
    var firmwareVersion = -1
    var bootCount = -1
    var key: Data?
    
    var listener: DeviceListener?
    
    var compositeDisposable: CompositeDisposable?
    
    var connectionDisposable: Disposable?
    var peripheral: Peripheral? //TODO - should this just be bleDevice?
    
    var connectionStateDisposable: Disposable?
    var reconnectOnDisconnect = 0
    
    var timerDisposable: Disposable?
    
    var retryTime = 0.5
    
    
    
    
    public init(scanResult: ScannedPeripheral) {
        super.init()
        
        bleDevice = scanResult.peripheral
        setManufacturerSpecificData(scanResult: scanResult)
    }
    
    func setManufacturerSpecificData(scanResult: ScannedPeripheral) {
        let msd = scanResult.advertisementData.manufacturerData
        if(msd != nil) {
            setSerial(msd: msd!)
            setFirmware(msd: msd!)
            setBootCount(msd: msd!)
        }
    }
    
    func setSerial(msd: Data) {
        if(msd.count >= 6) {
            let a = (100000 * UInt32(msd[2]))
            let b = (10000 * UInt32(msd[3]))
            let c = (UInt32(msd[4]) << 12) + (UInt32(msd[5]) << 8)
            let serialInt = a + b + c + (UInt32(msd[6]) << 4) + UInt32(msd[7])
            serial = String(serialInt)
        }
    }
    
    func setFirmware(msd: Data) {
        firmwareVersion = (Int(msd[8]) << 8) + Int(msd[9])
        /*print("PalDevice: setFirmware: FW: " + String(firmwareVersion))
        print("PalDevice: setFirmware: MSB: " + String(msd[8]) + " LSB: " + String(msd[9]))
        print("PalDevice: setFirmware: MSB: " + String((Int(msd[8]) << 8)) + " LSB: " + String(Int(msd[9])))*/
    }
    
    func setBootCount(msd: Data) {
        bootCount = Int(msd[11])
    }
    
    //Update these to optionals if possible
    @objc public func getName() -> String? {
        if(bleDevice == nil) {
            return nil
        }
        if let name = bleDevice.name {
            return name
        }
        return nil
    }
    
    @objc public func getMacAddress() -> String? {
        if(bleDevice == nil) {
            return nil
        }
        return "not avalible in iOS"
    }
    
    @objc public func getSerial() -> String? {
        return serial
    }
    
    @objc public func getFirmwareVersion() -> Int {
        return firmwareVersion
    }
    
    @objc public func getBootCount() -> Int {
        return bootCount
    }
    
    
    @objc public func connect(key: String?, listener: DeviceListener) {
        reconnectOnDisconnect = PalDevice.RECONNECTION_ATTEMPTS
        setListener(listener: listener)
        
        if(key != nil) {
            print("PalDevice: connect: key: ", key!);
            if(key!.count == 24 || key!.count == 25) {
                convertStringToKey(keyBase64: key!)
            } else if(key!.count != 0) {
                sendInvalidEncryptionKey()
                return
            }
        } else {
            print("PalDevice: connect: no key");
        }
        connect()
    }
    
    @objc public func isConnected() -> Bool {
        return bleDevice != nil && bleDevice.isConnected
    }
    
    @objc public func disconnect() {
        dispose()
    }
    
    func connect() {}
    func dispose() {}
    
    
    func setListener(listener: DeviceListener) {
        self.listener = listener
    }
    
    @objc public func hasDeviceListener() -> Bool {
        return listener != nil
    }
    
    func convertStringToKey(keyBase64: String?) -> Data? {
        print("PalDevice: convertingStringToKey: Starting");
        if(keyBase64 == nil) {
            return nil
        }
        //let keyString = keyBase64!.replacingOccurrences(of: "_", with: "/").replacingOccurrences(of: "-", with: "+")
        //key = Data(base64Encoded: keyString, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)
        
        key = Data.fromBase64UrlString(base64String: keyBase64!)
        print("PalDevice: convertingStringToKey: Done: ", key?.toHexString() ?? "Error");
        
        return key
    }
    
    func subscribeToConnectionState() {
        if(connectionStateDisposable != nil) {
            return
        }
        
        connectionStateDisposable = bleDevice.observeConnection()
            .do(onCompleted: {
                print("PalBle: subscribeToConnectionState: observation ended")
                self.connectionStateDisposable = nil
                if(self.compositeDisposable == nil) {
                    self.compositeDisposable = CompositeDisposable()
                } else {
                    print("PalBle: subscribeToConnectionState: Disposable not disposed")
                }
                if(self.hasDeviceListener()) {
                    self.listener!.onDisconnected()
                }
            })
            .subscribe(onNext: onConnectionStateResult)
    }
    
    func onConnectionStateResult(connected: Bool) {
        print("PalDevice: onConnectionStateResult: " + (connected ? "Connected" : "Disconnected"))
        if(!connected) {
            if(reconnectOnDisconnect > 0) {
                timerDisposable = Completable.empty().delay(retryTime, scheduler: MainScheduler.instance)
                    .subscribe({ (_) in
                        self.retryTime = 0.5
                        if(self.reconnectOnDisconnect < PalDevice.RECONNECTION_ATTEMPTS) {
                            self.sendRetry(triesRemaining: self.reconnectOnDisconnect)
                        }
                        self.connect()
                        self.timerDisposable!.dispose()
                    })
            } else {
                connectionStateDisposable?.dispose()
            }
            reconnectOnDisconnect -= 1
        }
    }
    
    
    
    
    
    
    func dataWithHexString(hex: String) -> Data {
        var hex = hex
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
    /*func onConnectionStateResult(connectionState: Event<Bool>) {
        print(connectionState);
    }
    
    func onConnectionStateError() {
        
    }*/
    
    func sendInvalidEncryptionKey() {
        if(hasDeviceListener()) {
            listener!.onInvalidEncryptionKey();
        }
    }
    
    func throwError(error: Error) {
        if(hasDeviceListener()) {
            listener!.onDeviceError(error: error)
        }
    }
    
    func sendOnConnected() {
        print("PalDevice: sendOnConnected: Enter")
        if(hasDeviceListener()) {
            print("PalDevice: sendOnConnected: Sending")
            listener!.onConnected(device: self)
        } else {
            print("PalDevice: sendOnConnected: No listener")
        }
    }
    
    func sendRetry(triesRemaining: Int) {
        if(hasDeviceListener()) {
            listener!.onRetrying(triesRemaining: triesRemaining)
        }
    }

    
    
    
    
    
    
}



/*
//Encryption
var m_key: Data?
//var updatekey: Bool = false //Flags if this is a new key or an updated key
var m_salt: Data?


//MARK: Encryption
func secureConnection() {
    message("Securing connection")
    
    fetchSalt()
}


func fetchSalt() {
    if(m_salt == nil) {
        if(m_connecionAttempted > 0 && self.saltChar != nil) {
            //m_connecionAttempted -= 1
            message("Fetching salt");
            SitfitCloudComms.sharedInstance.logEntry(code: 230, extraInfo: "Get salt")
            self.m_sitfitPeripheral.readValue(for: self.saltChar!)
            //m_scanTimer = Timer.scheduledTimer(timeInterval: Double(3), target: self, selector: #selector(SitBT.fetchSalt), userInfo: nil, repeats: false)
        } else {
            SitfitCloudComms.sharedInstance.logEntry(code: 415, extraInfo: "Get salt failed")
            m_userTry = SITBT_ERROR_BLE_CONNECTION_FAILED
            disconnect()
        }
    } else {
        SitfitCloudComms.sharedInstance.logEntry(code: 420, extraInfo: "Already salt")
        m_userTry = SITBT_ERROR_BLE_CONNECTION_FAILED
        disconnect()
    }
}



func generateKey() {
    message("Generating key")
    
    //Initilise NSDatas
    let tempBytes:[UInt8] = [0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1]
    m_key = Data(bytes: UnsafePointer<UInt8>(tempBytes), count: 16)
    let keyPointer = UnsafeMutablePointer<UInt8>(mutating: (m_key! as NSData).bytes.bindMemory(to: UInt8.self, capacity: m_key!.count))
    SecRandomCopyBytes(kSecRandomDefault, 16, keyPointer)
    
    message("Key generated: " + m_key!.toHexString())
    m_salt = nil
    
    
    //Save the key as soon as it's generated
    m_delegate!.saveKey(m_key!)
    
}


func decryptData(_ encryptedData: Data) -> Data? {
    if encryptedData.count == 16 {
        message("Encrypted data: " + encryptedData.toHexString())
        
        let result = NSMutableData(length: 16)!
        let keyPointer = UnsafeMutablePointer<UInt8>(mutating: (m_key! as NSData).bytes.bindMemory(to: UInt8.self, capacity: m_key!.count))
        let keyLength = size_t(kCCKeySizeAES128)
        let saltPointer = UnsafeMutablePointer<UInt8>(mutating: (m_salt! as NSData).bytes.bindMemory(to: UInt8.self, capacity: m_salt!.count))
        let dataPointer = UnsafeMutablePointer<UInt8>(mutating: (encryptedData as NSData).bytes.bindMemory(to: UInt8.self, capacity: encryptedData.count))
        let operation: CCOperation = UInt32(kCCDecrypt)
        let algoritm: CCAlgorithm = UInt32(kCCAlgorithmAES128)
        
        var numBytesDecrypted: size_t = 0
        
        let decryptionStatus = CCCrypt(operation,
                                       algoritm,
                                       0x0000,
                                       keyPointer, keyLength,
                                       saltPointer,
                                       dataPointer, size_t(16),
                                       result.mutableBytes, result.length,
                                       &numBytesDecrypted)
        
        if UInt32(decryptionStatus) == UInt32(kCCSuccess) {
            message("Decrypted data: " + result.toHexString())
            
            //Fiddle the thing
            /*for i in (result as NSArray as [UInt8]) {
             result[i] = UInt8(result[i] ^ 48)
             }*/
            
            return result as Data
        } else {
            message("Decryption failed \(decryptionStatus)")
            SitfitCloudComms.sharedInstance.logEntry(code: 417, extraInfo: "Decryption failed")
            return nil
        }
    }
    
    message("Data is not 16 bytes long (\(encryptedData.count))")
    SitfitCloudComms.sharedInstance.logEntry(code: 417, extraInfo: "Decryption failed")
    return nil
}
 */

