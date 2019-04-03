//
//  PalActivatorV2.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 16/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth

enum PalActivatorV2Characteristic: String, CharacteristicIdentifier {
    case today =            "46e73201-f545-430c-b11f-54697f3103f4"
    case step =             "46e73202-f545-430c-b11f-54697f3103f4"
    case upright =          "46e73203-f545-430c-b11f-54697f3103f4"
    case sedentary =        "46e73204-f545-430c-b11f-54697f3103f4"
    case sedPercentage =    "46e73205-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    //Service to which characteristic belongs
    var service: ServiceIdentifier {
        switch self {
        case .today, .step, .upright, .sedentary, .sedPercentage:
            return PalActivatorV2Service.activator
        }
    }
}

enum PalActivatorV2Service: String, ServiceIdentifier {
    case activator = "46e73200-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

@objc public class PalActivatorV2: PalActivator {
    static let P8C_TODAY_CHARACTERISTIC_UUID =                   UUID.init(uuidString: "46e73201-f545-430c-b11f-54697f3103f4")
    static let P8C_STEPS_CHARACTERISTIC_UUID =                   UUID.init(uuidString: "46e73202-f545-430c-b11f-54697f3103f4")
    static let P8C_UPRIGHT_CHARACTERISTIC_UUID =                 UUID.init(uuidString: "46e73203-f545-430c-b11f-54697f3103f4")
    static let P8C_SEDENTARY_CHARACTERISTIC_UUID =               UUID.init(uuidString: "46e73204-f545-430c-b11f-54697f3103f4")
    static let P8C_SEDENTARY_PERCENTAGE_CHARACTERISTIC_UUID =    UUID.init(uuidString: "46e73205-f545-430c-b11f-54697f3103f4")
    
    static let COMMAND_SET_HAPTIC_OFF =     "C48AFA915F3BCA3A6F34BB3AC334E95B"
    static let COMMAND_SET_HAPTIC_ON =      "C48AFA91DD3AC90C0C331AAEC3361CCE"
    
    static let COMMAND_SET_MODE_SLEEP =     "D48AFA913A"
    
    var stage0 = false
    var stage1 = false
    
    
    public override init(scanResult: ScannedPeripheral) {
        //print("PalBleSwift: PalActivatorV2: init")
        super.init(scanResult: scanResult)
    }
    
    override public func setHapticFeedback(on: Bool) -> Bool {
        if(mode != Mode.FIELD) {
            print("PalBleSwift: PalActivatorV2: setHapticFeedback: Not in field mode")
            return false
        }
        
        if(compositeDisposable != nil) {
            print("PalBleSwift: PalActivatorV2: setHapticFeedback: Already connected")
            return false
        }
        
        print("PalBleSwift: PalActivatorV2: setHapticFeedback: Connecting to set haptic")
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .flatMapFirst { $0.writeValue(Data.fromHexString(string: (on ? PalActivatorV2.COMMAND_SET_HAPTIC_ON : PalActivatorV2.COMMAND_SET_HAPTIC_OFF)), for: PalDeviceCharacteristic.setup, type: .withResponse) }
            .subscribe(onNext: onHapticResult, onError: onHapticError)) == nil) {
            return false
        }
        return true
    }
    
    func onHapticResult(char: Characteristic) {
        print("PalBleSwift: PalActivatorV2: onHapticResult: Haptic command sent - " + (char.value?.hexadecimalString ?? "value not found"))
        dispose()
        sendOnHapticSet(on: (char.value?.hexadecimalString)! == PalActivatorV2.COMMAND_SET_HAPTIC_ON)
    }
    
    func onHapticError(error: Error) {
        print("PalBleSwift: PalActivatorV2: onHapticError: " + error.localizedDescription)
        dispose()
        throwError(error: error)
    }
    
    
    override public func setSleep() {
        if(mode == Mode.SLEEP) {
            print("PalBleSwift: PalActivatorV2: setSleep: Already in sleep mode")
            return
        }
        if(compositeDisposable != nil) {
            print("PalBleSwift: PalActivatorV2: setSleep: Already connected")
            return
        }
        
        print("PalBleSwift: PalActivatorV2: setSleep: Connecting to put to sleep")
        reconnectOnDisconnect = 0
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .flatMapFirst { $0.writeValue(Data.fromHexString(string: PalActivatorV2.COMMAND_SET_MODE_SLEEP), for: PalDeviceCharacteristic.setup, type: .withResponse) }
            .subscribe(onNext: onSleepResult, onError: onSleepError)) == nil) {
            print("PalBleSwift: PalActivatorV2: setSleep: Error")
        }
    }
    
    private func onSleepResult(char: Characteristic) {
        reconnectOnDisconnect = 1
        print("PalBleSwift: PalActivatorV2: onSleepResult: Sleep command sent - " + (char.value?.hexadecimalString ?? "value not found"))
        dispose()
        mode = Mode.SLEEP
        sendOnSleep()
    }
    
    private func onSleepError(error: Error) {
        print("PalBleSwift: PalActivatorV2: onSleepError: enter");
        switch(error) {
        case BluetoothError.peripheralDisconnected(_, _):
            if(reconnectOnDisconnect > 0) {
                print("PalBleSwift: PalActivatorV2: onSleepError: disconnected")
                break
            }
        default:
            print("PalBleSwift: PalActivatorV2: onSleepError: " + (error as! BluetoothError).description)
            throwError(error: error)
        }
        dispose()
    }
    
    
    override func connectToWake() {
        connectToWake(wakingCharacteristicIdentifier: PalDeviceCharacteristic.setup)
    }
    
    override func encryptThenFetchAllData(key: Data) {
        //encryptThenFetchAllData(key: key, encryptionCharacteristic: PalDevice.P8C_ENCRYPTION_CHARACTERISTIC_UUID!)
        encryptThenFetchAllData(key: key, characteristic: PalDeviceCharacteristic.encryption)
    }
    
    override func getEncryptionCheck(peripheral: Peripheral) -> PrimitiveSequence<SingleTrait, (Characteristic, Characteristic)> {
        return PrimitiveSequence.zip(
            peripheral.readValue(for: DeviceCharacteristic.encryption),
            peripheral.readValue(for: DeviceCharacteristic.time))
        { (encryption, time) in
            print("PalBleSwift: PalActivatorV2: getEncryptionCheck: Info: \(encryption.value?.hexadecimalString ?? "no value")")
            print("PalBleSwift: PalActivatorV2: getEncryptionCheck: Data: \(time.value?.hexadecimalString ?? "no value")")
            return (encryption, time)
        }
    }
    
    
    override func fetchAllData() {
        stage0 = false
        stage1 = false
        
        if(compositeDisposable!.insert(peripheral!.writeValue(getTimeFromPhone(), for: PalDeviceCharacteristic.time, type: .withResponse)
            .flatMap { char in
                PrimitiveSequence.zip(
                    self.peripheral!.readValue(for: PalActivatorV2Characteristic.today),
                    self.peripheral!.readValue(for: PalActivatorV2Characteristic.sedPercentage),
                    self.peripheral!.readValue(for: PalActivatorV2Characteristic.step),
                    self.peripheral!.readValue(for: PalActivatorV2Characteristic.upright),
                    self.peripheral!.readValue(for: PalActivatorV2Characteristic.sedentary))
                { (today, sedPer, step, upright, sedentary) in
                    return (today, sedPer, step, upright, sedentary)
                }}
            .subscribe(onSuccess: onFetchResult, onError: onFetchError)) == nil) {
            print("PalBleSwift: PalActivatorV2: fetchAllData: Error")
        }
        
        
        /*peripheral!.writeValue(Data.fromHexString(string: PalActivatorV2.COMMAND_SET_HAPTIC_ON), for: PalDeviceCharacteristic.time, type: .withResponse)
         .subscribe(
         onNext: {
         PrimitiveSequence.zip(
         peripheral!.readValue(for: PalActivatorV2Characteristic.today),
         peripheral!.readValue(for: PalActivatorV2Characteristic.sedPercentage),
         peripheral!.readValue(for: PalActivatorV2Characteristic.step),
         peripheral!.readValue(for: PalActivatorV2Characteristic.upright),
         peripheral!.readValue(for: PalActivatorV2Characteristic.sedentary))
         { (today, sedPer, step, upright, sedentary) in
         return (today, sedPer, step, upright, sedentary)
         }
         .subscribe(onSuccess: onFetchResult, onError: onFetchError)
         },
         onError: { err in
         print("fetchAllData: Error: \(err)")
         })*/
    }
    
    func disposeIfDone0() {
        stage0 = true
        if(stage1) {
            dispose()
        }
    }
    
    func disposeIfDone1() {
        stage1 = true
        if(stage0) {
            dispose()
        }
    }
    
    
    func sendOnHapticSet(on: Bool) {
        if(hasActivatorListener()) {
            activatorListener!.onHapticSet(success: on)
        }
    }
    
    func sendOnSleep() {
        if(hasActivatorListener()) {
            activatorListener!.onSleep()
        }
    }
    
    
    /*
     override func getEncryptionCheckSingle() -> Single<Pair<Data, Data>> {
        return Single.zip()
    }
     
     override func getDataFetchSingle() -> Single<PalActivatorRawData> {
     }
     
    */
    
    
}
