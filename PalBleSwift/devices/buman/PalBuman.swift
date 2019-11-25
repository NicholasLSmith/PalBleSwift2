//
//  PalBuman.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 03/07/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth

enum PalBumanCharacteristic: String, CharacteristicIdentifier {
    case spike = "46e73601-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    var service: ServiceIdentifier {
        switch self {
        case .spike:
            return PalBumanService.buman
        }
    }
}

enum PalBumanService: String, ServiceIdentifier {
    case buman = "46e73600-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

@objc public class PalBuman: PalDevice {
    private var bumanListener: BumanListener?
    
    @objc public override func setListener(listener: PalDeviceListener) {
        if let bListener = listener as? BumanListener {
            bumanListener = bListener
        }
        super.setListener(listener: listener)
    }
    
    override func connect() {
        subscribeToConnectionState()
        
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .do(onNext: { connectedPer in
                print("PalBleSwift: PalBuman: connect: Connected")
                self.peripheral = connectedPer
                self.sendOnConnected()
            }, onDispose: {
                self.compositeDisposable = nil
            })
            .flatMapFirst { $0.observeValueUpdateAndSetNotification(for: PalBumanCharacteristic.spike)}
            .subscribe(onNext: self.onNotification)) == nil) {
            print("PalBleSwift: PalBuman: connect: Error")
        }
    }
    
    func onNotification(char: Characteristic) {
        let bytes = char.value
        if(bytes == nil || bytes?.count == 0) {
            return;
        }
        
        if(bytes!.count == 1) {
            sendOnSpike(bytes: bytes!)
        } else {
            print("PalBleSwift: PalBuman: onNotification: Unexpected notification: " + bytes!.toHexString())
        }
    }
    
    func sendOnSpike(bytes: Data) {
        if(bumanListener != nil) {
            bumanListener!.onSpike(z: Int(bytes[0] & 0xFF))
        }
    }
}
