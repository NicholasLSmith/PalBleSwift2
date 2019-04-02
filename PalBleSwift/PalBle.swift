//
//  PalBle.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 09/07/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift

@objc public class PalBle: NSObject {
    var rxBleClient: CentralManager!
    
    var scanListener: ScanListener?
    var connectListener: ConnectListener?
    var deviceListener: DeviceListener?
    
    var mainDisposable: Disposable?
    var scanDeviceResults = [PalDevice]()
    
    var scanParameters: ScanParameters?
    
    var serial: Data?
    var serialString: String?
    var key: String?
    
    var scanStopped = false;
    var timeOut = 10;
    
    
    @objc override public init() {
        rxBleClient = CentralManager(queue: .main)
    }
    
    @objc public func setListener(listener: PalListener) {
        print("PalBle: setListener: Called")
        if(listener is ScanListener) {
            scanListener = (listener as! ScanListener)
        }
        if(listener is ConnectListener) {
            connectListener = (listener as! ConnectListener)
        }
        if(listener is DeviceListener) {
            deviceListener = (listener as! DeviceListener)
        }
    }
    
    
    @objc public func isScanning() -> Bool {
        return mainDisposable != nil /*&& !(mainDisposable?.disposed(by: <#T##DisposeBag#>))*/ //no isDisposed method
    }
    
    @objc public func startScan(scanParameters: ScanParameters) {
        self.scanParameters = scanParameters
        startScan()
    }
    
    @objc public func startScan() {
        if(!isScanning()) {
            subscribeToScan()
        }
    }
    
    @objc public func getScanResults() -> [PalDevice] {
        return scanDeviceResults
    }
    
    @objc public func stopScan() {
        scanStopped = true
        if let disposable = self.mainDisposable {
            disposable.dispose()
        }
    }
    
    
    @objc public func connect(serial: String) {
        print("Connecting with serial only")
        connect(serial: serial, key: nil)
    }
    
    @objc public func connect(serial: String, key: String?) {
        print("Connecting with serial and key")
        connect(serial: serial, key: key, timeOut: 10)
    }
    
    @objc public func connect(serial: String, key: String?, timeOut: Int) {
        print("Connecting with serial, key, and timeout")
        if(serial.count != 6) {
            print("Invalid serial: " + String(serial.count))
            return
        }
        self.serialString = serial
        self.serial = stringSerialToData(serial: serial)
        self.key = key
        self.timeOut = timeOut
        
        connect()
    }
    
    @objc public func generateKey() -> String {
        var key = Data()
        let tempBytes:[UInt8] = [0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1]
        key = Data(bytes: UnsafePointer<UInt8>(tempBytes), count: 16)
        let keyPointer = UnsafeMutablePointer<UInt8>(mutating: (key as NSData).bytes.bindMemory(to: UInt8.self, capacity: key.count))
        let status = SecRandomCopyBytes(kSecRandomDefault, 16, keyPointer)
        
        if(status == errSecSuccess) {
            return key.base64UrlString
        }
        return ""
    }
    
    
    private func subscribeToScan() {
        scanStopped = false
        scanDeviceResults.removeAll()
        
        var timeout = 15.0
        if(scanParameters != nil) {
            timeout = Double(scanParameters!.scanTimeout)
        }
        
        mainDisposable = rxBleClient.observeState()
            .startWith(rxBleClient.state)
            .filter { $0 == .poweredOn || $0 == .poweredOff }
            .take(1)
            .flatMap { _ in self.rxBleClient.scanForPeripherals(withServices: nil) }
            .timeout(timeout, scheduler: MainScheduler.instance)
            .do(onCompleted: self.scanDone)
            .subscribe(onNext: onScanResult, onError: onScanError)
    }
    
    func onScanResult(scanResult: ScannedPeripheral) {
        if(scanResult.advertisementData.localName == nil) {
            return
        }
        
        let foundDevice = PalDeviceFactory.getDevice(scanResult: scanResult)
        if(foundDevice == nil) {
            return;
        }
        if(foundDevice!.getSerial() == nil) {
            return
        }
        
        if(scanParameters != nil && scanParameters!.serialList.count != 0) {
            if(!scanParameters!.serialList.contains((foundDevice?.getSerial())!)) {
                return
            }
        }
        
        if(updateScanDeviceList(foundDevice: foundDevice!)) {
            return;
        }
        appendScanDeviceList(foundDevice: foundDevice!)
    }
    
    func onScanError(error: Error) {
        if(error is BluetoothError) {
            handleBleScanException(bleScanException: error as! BluetoothError)
        } else if(error is RxError) {
            print("RXError: ", error.localizedDescription)
        }
    }
    
    private func scanDone() {
        if(!scanStopped) {
            onScanTimeout()
        }
        dispose()
    }
    
    private func dispose() {
        mainDisposable = nil
    }
    
    
    func connect() {
        print("Running connect")
        if(!hasDeviceListener()) {
            print("No device listener")
            return
        }
        if(isScanning()) {
            stopScan()
        }
        subscribeToConnect()
    }
    
    func subscribeToConnect() {
        scanStopped = false;
        mainDisposable = rxBleClient.observeState()
            .startWith(rxBleClient.state)
            .filter { $0 == .poweredOn }
            .take(1)
            .flatMap { _ in self.rxBleClient.scanForPeripherals(withServices: nil) }
            .timeout(Double(timeOut), scheduler: MainScheduler.instance)
            .do(onCompleted: self.connectionDone)
            .subscribe(onNext: onConnectResult, onError: onConnectError)
    }
    
    func onConnectResult(scanResult: ScannedPeripheral) {
        let foundDevice = PalDeviceFactory.getDevice(scanResult: scanResult)
        if(!hasCorrectSerial(foundDevice: foundDevice)) {
            return
        }
        stopScan()
        if(foundDevice is PalActivatorV2) {
            print("PalBle: onConnectResult: Connecting to v2 device");
        } else {
            print("PalBle: onConnectResult: Connecting to v1 device");
        }
        onDeviceFound()
        connectToDevice(foundDevice: foundDevice!)
    }
    
    func connectToDevice(foundDevice: PalDevice) {
        if(hasDeviceListener()) {
            foundDevice.connect(key: key, listener: deviceListener!)
        }
    }
    
    func onConnectError(error: Error) {
        if(error is BluetoothError) {
            handleBleScanException(bleScanException: error as! BluetoothError)
        } else if(error is RxError) {
            if((error as! RxError).debugDescription.contains("timeout")) {
                throwBleError(message: "Bluetooth disabled", reason: 1)
            } else {
                throwBleError(message: "Internal error error", reason: 7)
            }
        }
    }
    
    private func connectionDone() {
        if(!scanStopped) {
            onConnectTimeout()
        }
        dispose()
    }
    
    
    
    private func hasCorrectSerial(foundDevice: PalDevice?) -> Bool {
        return foundDevice != nil && foundDevice!.getSerial() != nil && serialString != nil && foundDevice!.getSerial()! == serialString!
    }
    
    private func appendScanDeviceList(foundDevice: PalDevice) {
        scanDeviceResults.append(foundDevice);
        //scanDeviceResults.sort { $0.getMacAddress() < $1.getMacAddress() }
        onScanResultsChanged(device: foundDevice)
    }
    
    private func updateScanDeviceList(foundDevice: PalDevice) -> Bool {
        for var device in scanDeviceResults {
            if(device.getSerial() == foundDevice.getSerial()) {
                device = foundDevice
                return true
            }
        }
        return false
    }
    
    
    
    
    
    func stringSerialToData(serial: String) -> Data? {
        if(serial.count != 6) {
            return nil
        }
        var other = serial.data(using: .utf8)
        for i in 0 ... other!.count - 1 {
            other![i] -= 0x30
        }
        
        var result = other!
        var value = Int(result[2]) * 1000 + Int(result[3]) * 100 + Int(result[4]) * 10 + Int(result[5])
        result[2] = UInt8(value / 4096)
        value = value % 4096
        result[3] = UInt8(value / 256)
        value = value % 256
        result[4] = UInt8(value / 16)
        value = value % 16
        result[5] = UInt8(value)
        
        return result
    }
    
    
    
    func hasScanListener() -> Bool {
        return scanListener != nil
    }
    
    func hasConnectListener() -> Bool {
        return connectListener != nil
    }
    
    func hasDeviceListener() -> Bool {
        return deviceListener != nil
    }
    
    private func onScanResultsChanged(device: PalDevice) {
        if(hasScanListener()) {
            scanListener!.onScanResultsChanged();
        }
    }
    
    private func onScanTimeout() {
        if(hasScanListener()) {
            scanListener!.onScanTimeOut();
        }
    }
    
    private func throwBleError(scanException: BluetoothError) {
        throwBleError(message: "", scanException: scanException);
    }
    
    private func throwBleError(message: String, scanException: BluetoothError) {
        throwBleError(message: scanException.description, reason: scanException.getReason())
    }
    
    private func throwBleError(message: String, reason: Int) {
        if(hasScanListener()) {
            scanListener!.onScanError(scanException: BleScanException(message: message, reason: reason))
        } else if(hasConnectListener()) {
            connectListener!.onConnectError(connectionException: BleScanException(message: message, reason: reason))
        } else {
            print("PalBle: throwBleError: " + message);
        }
    }
    
    func onDeviceFound() {
        if(hasConnectListener()) {
            connectListener!.onDeviceFound()
        }
    }
    
    
    
    
    private func onConnectTimeout() {
        if(hasConnectListener()) {
            connectListener!.onConnectTimeout()
        }
    }
    
    private func handleBleScanException(bleScanException: BluetoothError) {
        throwBleError(message: String(describing: bleScanException), scanException: bleScanException)
    }
    
    
    
    
    
    
    
    @objc public func getSomething() -> String {
        return "Hello";
    }
    
    @objc public func printSomething() {
        print("Hello");
    }
    
    @objc static public func shout() {
        print("HELLO!");
    }
    
    
    
    
    
    
    
    @objc public func sayHeelo() {
        print("Heelo")
    }
}
