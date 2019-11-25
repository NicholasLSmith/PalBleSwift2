//
//  PalScan.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 22/11/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift

class PalScan: NSObject {
    var listener: PalScanListener!
    var rxBleClient: CentralManager!
    var disposable: Disposable?

    var parameters: ScanParameters?
    var scanDeviceResults = [PalDevice]()
    
    var stopped = false
    var error: Error?
    
    public init(rxBleClient: CentralManager, listener: PalScanListener) {
        self.rxBleClient = rxBleClient
        self.listener = listener
    }
    
    func isScanning() -> Bool {
        return disposable == nil
    }
    
    func setParameters(parameters: ScanParameters) {
        self.parameters = parameters
    }
    
    func start() {
        if(!isScanning()) {
            subscribe();
        }
    }
    
    func getResults() -> [PalDevice] {
        return scanDeviceResults
    }
    
    func stop() {
        stopped = true
        if(isScanning()) {
            disposable?.dispose()
        }
    }
    
    private func subscribe() {
        stopped = false
        scanDeviceResults.removeAll()
        
        var timeout = 15.0
        if(parameters != nil) {
            timeout = Double(parameters!.scanTimeout)
        }
        
        disposable = rxBleClient.observeState()
            .startWith(rxBleClient.state)
            .filter { $0 == .poweredOn || $0 == .poweredOff }
            .take(1)
            .flatMap { _ in self.rxBleClient.scanForPeripherals(withServices: nil) }
            .timeout(timeout, scheduler: MainScheduler.instance)
            .do(onDispose: onDone)
            .subscribe(onNext: onResult, onError: onError)
    }
    
    func onResult(scanResult: ScannedPeripheral) {
        if(stopped || scanResult.advertisementData.localName == nil) {
            return
        }
        
        let foundDevice = PalDeviceFactory.getDevice(scanResult: scanResult)
        if(foundDevice == nil || foundDevice!.getSerial() == nil) {
            return
        }
        
        if(parameters != nil) {
            if(parameters!.deviceFamily != ScanParameters.ALL) {
                if(scanResult.advertisementData.localName! != parameters!.getDeviceFamily()) {
                    return
                }
            }
            
            if(parameters!.serialList.count != 0 && !parameters!.serialList.contains((foundDevice?.getSerial())!)) {
                return
            }
        }
        
        if(!updateResults(foundDevice: foundDevice!)) {
            appendResults(foundDevice: foundDevice!)
        }
    }
    
    func onError(error: Error) {
        self.error = error
        if case RxError.timeout = error as! RxError {
            if(!stopped) {
                listener!.onScanTimeOut()
            }
        } else {
            listener!.onScanError(error: error)
        }
    }
    
    func onDone() {
        disposable = nil
        if(error == nil && !stopped) {
            listener?.onScanTimeOut()
        }
    }
    
    private func appendResults(foundDevice: PalDevice) {
        print("PalBleSwift: PalScan: appendResults: New device found: " + foundDevice.getSerial()! )
        scanDeviceResults.append(foundDevice);
        scanDeviceResults.sort { $0.getMacAddress()! < $1.getMacAddress()! }
        listener!.onScanResultsChanged(device: foundDevice)
    }
    
    private func updateResults(foundDevice: PalDevice) -> Bool {
        for var device in scanDeviceResults {
            if(device.getSerial() == foundDevice.getSerial()) {
                device = foundDevice
                return true
            }
        }
        return false
    }
}
