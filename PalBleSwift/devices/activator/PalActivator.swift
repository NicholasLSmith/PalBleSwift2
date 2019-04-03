//
//  PalActivator.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CryptoSwift

enum PalActivatorError: Error {
    case invalidMethod
}

@objc public class PalActivator: PalDevice {
    private let COMMAND_WAKE_UP = "D48AFA91FC"
    enum Mode {
        case SERVICE, SLEEP, FIELD
    }
    var mode = Mode.SERVICE
    
    var activatorListener: ActivatorListener?
    
    private var salt: Data?
    private var rawParameters: Data?
    
    private var palActivatorData: PalActivatorData?
    
    
    public override init(scanResult: ScannedPeripheral) {
        super.init(scanResult: scanResult)
    }
    
    public override func setManufacturerSpecificData(scanResult: ScannedPeripheral) {
        let msd = scanResult.advertisementData.manufacturerData
        
        if(msd != nil) {
            setSerial(msd: msd!)
            setFirmware(msd: msd!)
            setBootCount(msd: msd!)
            setMode(msd: msd!)
        }
    }
    
    @objc override public func setListener(listener: DeviceListener) {
        if let actListener = listener as? ActivatorListener {
            activatorListener = actListener
        }
        super.setListener(listener: listener)
    }
    
    @objc public func setEncryptionKey(keyBase64: String) {
        convertStringToKey(keyBase64: keyBase64)
        if(hasEncryptionKey()) {
            if(hasValidEncryptionKey()) {
                print("PalBleSwift: PalActivator: setEncryptionKey: fetch all data");
                fetchAllData()
            } else {
                print("PalBleSwift: PalActivator: setEncryptionKey: encrypted then fetch all data");
                encryptThenFetchAllData(key: key!)
            }
        } else {
            print("PalBleSwift: PalActivator: setEncryptionKey: disconnect");
            disconnect()
        }
    }
    
    @objc public func getSummaries() -> PalActivatorData {
        return palActivatorData!
    }
    
    @objc public func setHapticFeedback(on: Bool) -> Bool {
        return false
    }
    
    @objc public func setSleep() {
        print("PalActivator: setSleep: Method not supported for older Activator models")
    }
    
    
    
    override func connect() {
        subscribeToConnectionState()
        if(mode == Mode.SLEEP || mode == Mode.SERVICE) {
            connectToWake()
        } else {
            connectToFetchData()
        }
    }
    

    override func dispose() {
        reconnectOnDisconnect = 0
        if(connectionDisposable != nil) {
            connectionDisposable!.dispose()
        }
        if(compositeDisposable != nil) {
            compositeDisposable!.dispose()
        }
    }
    
    private func setMode(msd: Data) {
        let mode = UInt8(msd[10])
        if(mode == 0x3A) {
            self.mode = Mode.SLEEP
        } else if(mode == 0xB6) {
            self.mode = Mode.SERVICE
        } else {
            self.mode = Mode.FIELD
        }
    }
    
    @objc public func getMode() -> String {
        switch mode {
        case Mode.SERVICE:
            return "service"
        case Mode.SLEEP:
            return "sleep"
        case Mode.FIELD:
            return "field"
        }
    }
    
    
    func connectToWake() {}    
    
    func connectToWake(wakingCharacteristicIdentifier: CharacteristicIdentifier) {
        print("PalBleSwift: PalActivator: connectToWake: Wake starting")
        sendOnWaking()
        
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .do(onNext: { connectedPer in
                print("PalBleSwift: PalActivator: connectToWake: onNext")
            })
            .flatMapFirst { $0.writeValue(Data.fromHexString(string: self.COMMAND_WAKE_UP), for: wakingCharacteristicIdentifier, type: .withResponse) }
            .subscribe(onNext: self.onWakeResult, onError: self.onWakeError)) == nil) {
            print("PalBleSwift: PalActivator: connectToWake: Error")
        }
    }
    
    func onWakeResult(char: Characteristic) {
        print("PalBleSwift: PalActivator: onWakeResult: Wake command sent - " + (char.value?.hexadecimalString ?? "value not found"))
        reconnectOnDisconnect = PalDevice.RECONNECTION_ATTEMPTS + 1
        retryTime = 1.0
        mode = Mode.FIELD
        compositeDisposable!.dispose()
        sendOnWoken()
    }
    
    func onWakeError(error: Error) {
        print("PalBleSwift: PalActivator: onWakeError: enter");
        switch(error) {
        case BluetoothError.peripheralDisconnected(_, _):
            if(reconnectOnDisconnect > 0) {
                print("PalBleSwift: PalActivator: onWakeError: disconnected")
                break
            }
        default:
            print("PalBleSwift: PalActivator: onWakeError: " + (error as! BluetoothError).description)
            throwError(error: error)
        }
        compositeDisposable?.dispose()
    }
    
    
    private func connectToFetchData() {
        print("PalBleSwift: PalActivator: connectToFetchData: Starting")
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .do(onNext: { connectedPer in
                print("PalActivator: connectToFetchData: Connected")
                self.peripheral = connectedPer
                self.sendOnConnected()
            }, onDispose: {
                self.compositeDisposable = nil
            })
            .flatMapFirst { self.getEncryptionCheck(peripheral: $0) }
            .subscribe(onNext: self.onEncryptionCheckResult, onError: self.onFetchError)) == nil) {
            print("PalBleSwift: PalActivator: connectToFetchData: Error")
        }
    }
    
    func getEncryptionCheck(peripheral: Peripheral) -> PrimitiveSequence<SingleTrait, (Characteristic, Characteristic)> {
        return PrimitiveSequence.zip(
            peripheral.readValue(for: DeviceCharacteristic.encryption),
            peripheral.readValue(for: DeviceCharacteristic.time))
        { (encryption, time) in
            return (encryption, time)
        }
    }
    
    /*func getEncryptionCheck(peripheral: Peripheral) throws -> PrimitiveSequence<SingleTrait, (Characteristic, Characteristic)> {
        throw PalActivatorError.invalidMethod
        
        return PrimitiveSequence.zip(
            peripheral.readValue(for: DeviceCharacteristic.encryption),
            peripheral.readValue(for: DeviceCharacteristic.time))
        { (encryption, time) in
            return (encryption, time)
        }
    }*/
    
    func onEncryptionCheckResult(first: Characteristic, second: Characteristic) {
        if(isEncrypted(data: first.value!)) {
            saveEncryptionCheck(first: first.value!, second: second.value!)
            if(!hasEncryptionKey()) {
                onExistingEncryptionKeyNeeded()
            } else if(!hasValidEncryptionKey()) {
                disconnect()
                onInvalidEncryptionKey()
            } else {
                fetchAllData()
            }
        } else {
            onNewEncryptionKeyNeeded()
        }
    }
    
    func isEncrypted(data: Data) -> Bool {
        return data.count == 16 && (data[0] != 0x0 || data[5] != 0x0 || data[10] != 0x0)
    }
    
    func saveEncryptionCheck(first: Data, second: Data) {
        salt = first
        for i in 0 ... salt!.count - 1 {
            salt![i] ^= 48
        }
        rawParameters = second
    }
    
    func hasEncryptionKey() -> Bool {
        return key != nil
    }
    
    func hasValidEncryptionKey() -> Bool {
        if(!hasEncryptionKey() || salt == nil ||
            rawParameters == nil || rawParameters?.count != 16) {
            return false
        }
        
        let parameters = decrypt(rawParameters!)
        if(parameters == nil || (parameters![14] & 0xFF) != 48 || (parameters![15] & 0xFF) != 48) {
            return false
        }
        palActivatorData = PalActivatorData();
        palActivatorData!.setAdvertisment(serial: getSerial()!, firmware: getFirmwareVersion(), bootCount: getBootCount())
        palActivatorData!.setParameters(parameter: parameters!)
        
        return true
    }
    
    
    func encryptThenFetchAllData(key: Data) {}
    
    func encryptThenFetchAllData(key: Data, characteristic: CharacteristicIdentifier) {
        if(compositeDisposable?.insert(peripheral!.writeValue(key, for: characteristic, type: .withResponse)
            .asObservable()
            .flatMapFirst({ (_) -> PrimitiveSequence<SingleTrait, (Characteristic, Characteristic)> in
                self.getEncryptionCheck(peripheral: self.peripheral!)
            })
            .subscribe(onNext: self.onEncryptionCheckResult, onError: self.onFetchError)) == nil) {
            print("PalBleSwift: PalActivator: encryptThenFetchAllData: Error")
        }
    }
    
    
    func fetchAllData() {}
    
    func getTimeFromPhone() -> Data {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier:"UTC")
        formatter.dateFormat = "yyyyMMdd"
        let palDate = formatter.date(from: "20170101")
        //print("getTimeFromPhone: \(palDate!)")
        let currentPhoneSecondsSincePalTime = Int(-(palDate!.timeIntervalSinceNow))
        //print("getTimeFromPhone: \(currentPhoneSecondsSincePalTime)")
        let currentPhoneTimeZone = TimeZone.current.secondsFromGMT() / 900
        //print("getTimeFromPhone: \(currentPhoneTimeZone)")
        
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let dayStart = cal.startOfDay(for: Date())
        let secondsSinceMidnight = Int(Date().timeIntervalSince(dayStart))
        //print("getTimeFromPhone: \(secondsSinceMidnight)")
        
        let result = Data([UInt8]([
            UInt8(truncatingIfNeeded: currentPhoneSecondsSincePalTime),
            UInt8(truncatingIfNeeded: (currentPhoneSecondsSincePalTime / 256)),
            UInt8(truncatingIfNeeded: (currentPhoneSecondsSincePalTime / 65536)),
            UInt8(truncatingIfNeeded: (currentPhoneSecondsSincePalTime / 16777216)),
            UInt8(truncatingIfNeeded: secondsSinceMidnight),
            UInt8(truncatingIfNeeded: (secondsSinceMidnight / 256)),
            UInt8(truncatingIfNeeded: (secondsSinceMidnight / 65536)),
            UInt8(truncatingIfNeeded: (secondsSinceMidnight / 16777216)),
            UInt8(truncatingIfNeeded: currentPhoneTimeZone),
            0xA3, 0x82, 0xF3, 0xCA, 0x5B, 0x23, 0x03]))
        
        return result
    }
    
    func onFetchResult(today: Characteristic, sedPer: Characteristic, step: Characteristic, upright: Characteristic, sedentary: Characteristic) {
        palActivatorData!.setData(
            daily: decrypt(today.value!)!,
            sedentaryPer: decrypt(sedPer.value!)!,
            step: decrypt(step.value!)!,
            upright: decrypt(upright.value!)!,
            sedentary: decrypt(sedentary.value!)!)
        sendOnSummariesRetrieved()
        dispose()
    }
    
    func onFetchError(error: Error) {
        if(reconnectOnDisconnect <= 1) {
            print("onFetchError: \(error)")
            throwError(error: error)
        }
        dispose()
    }
    
    
    func decrypt(_ encryptedData: Data) -> Data? {
        do {
            let aes = try AES(key: key!.bytes, blockMode: CBC(iv: salt!.bytes))
            var decrypted = try aes.decrypt(encryptedData.bytes)
            for i in  0...decrypted.count - 1 {
                decrypted[i] ^= 48
            }
            print("PalBleSwift: PalActivator: decrypt: \(decrypted.toHexString())")
            return Data(decrypted)
        } catch {
            print("PalBleSwift: PalActivator: Error: \(error)")
            return nil
        }
    }
    
    
    private func sendOnWaking() {
        if(hasActivatorListener()) {
            activatorListener!.onWaking()
        }
    }
    
    private func sendOnWoken() {
        if(hasActivatorListener()) {
            activatorListener!.onWoken()
        }
    }
    
    func onNewEncryptionKeyNeeded() {
        if(hasActivatorListener()) {
            activatorListener!.onNewEncryptionKeyNeeded()
        }
    }
    
    func onExistingEncryptionKeyNeeded() {
        if(hasActivatorListener()) {
            activatorListener!.onExistingEncryptionKeyNeeded()
        }
    }
    
    func onInvalidEncryptionKey() {
        if(hasActivatorListener()) {
            activatorListener!.onInvalidEncryptionKey()
        }
    }
    
    private func sendOnSummariesRetrieved() {
        if(hasActivatorListener()) {
            activatorListener!.onSummariesRetrieved()
        }
    }
    
    
    
    func hasActivatorListener() -> Bool {
        return activatorListener != nil
    }
    
    
    
}
