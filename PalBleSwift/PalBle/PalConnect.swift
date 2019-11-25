//
//  PalConnect.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 22/11/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift

enum ConnectError: Error {
    case nilSerial
    case nilListener
}

class PalConnect: NSObject {
    var listener: PalConnectListener!
    var rxBleClient: CentralManager!
    var disposable: Disposable?
    var deviceListener: PalDeviceListener?
    
    var stopped = false
    var error: Error?
    var timeout = 10
    
    var serial: String?
    var key: String?
    
    public init(rxBleClient: CentralManager, listener: PalConnectListener) {
        self.rxBleClient = rxBleClient
        self.listener = listener
    }
    
    func setKey(key: String) {
        self.key = key
    }
    
    func setTimeout(timeout_s: Int) {
        timeout = timeout_s
    }
    
    func setSerial(serial: String) {
        self.serial = serial
    }
    
    func setDeviceListener(listener: PalDeviceListener) {
        deviceListener = listener
    }
    
    func connect() throws {
        if (serial == nil) {
            throw ConnectError.nilSerial
        }
        if (deviceListener == nil) {
            throw ConnectError.nilListener
        }
        
        stopped = false
        error = nil
        disposable = rxBleClient.observeState()
            .startWith(rxBleClient.state)
            .filter { $0 == .poweredOn || $0 == .poweredOff }
            .take(1)
            .flatMap { _ in self.rxBleClient.scanForPeripherals(withServices: nil) }
            .timeout(Double(timeout), scheduler: MainScheduler.instance)
            .do(onDispose: onDone)
            .subscribe(onNext: onResult, onError: onError)
    }
    
    func onResult(scanResult: ScannedPeripheral) {
        if(scanResult.advertisementData.localName == nil) {
            return
        }
        
        let foundDevice = PalDeviceFactory.getDevice(scanResult: scanResult)
        if(!hasCorrectSerial(foundDevice: foundDevice)) {
            return
        }
        stop()
        listener.onDeviceFound(device: foundDevice!)
        connect(device: foundDevice!)
    }
    
    func connect(device: PalDevice) {
        if(deviceListener == nil) {
            listener.onConnectError(error: ConnectError.nilListener)
            return
        }
        
        device.connect(key: key, listener: deviceListener!)
    }
    
    func onError(error: Error) {
        self.error = error
        if case RxError.timeout = error as! RxError {
            if(!stopped) {
                listener!.onConnectTimeout()
            }
        } else {
            listener!.onConnectError(error: error)
        }
    }
    
    func onDone() {
        if (error == nil && !stopped) {
            listener.onConnectTimeout()
        }
    }
    
    private func stop() {
        stopped = true;
        if(isScanning()) {
            disposable?.dispose()
        }
    }
    
    private func isScanning() -> Bool {
        return disposable != nil
    }
    
    private func hasCorrectSerial(foundDevice: PalDevice?) -> Bool {
        return foundDevice != nil && foundDevice!.getSerial() != nil &&
            serial != nil && foundDevice!.getSerial()! == serial!
    }
}
