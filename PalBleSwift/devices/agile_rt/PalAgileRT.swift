//
//  PalAgileRT.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 06/06/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth

enum PalAgileRTCharacteristic: String, CharacteristicIdentifier {
    case state = "46e73601-f545-430c-b11f-54697f3103f4"
    case message = "46e73602-f545-430c-b11f-54697f3103f4"
    case command = "46e73603-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    var service: ServiceIdentifier {
        switch self {
        case .state, .message, .command:
            return PalAgileRTService.agileRT
        }
    }
}

enum PalAgileRTService: String, ServiceIdentifier {
    case agileRT = "46e73600-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

@objc public class PalAgileRT: PalDevice {
    private var agileRTListener: AgileRTListener?
    
    @objc public override func setListener(listener: DeviceListener) {
        if let agListener = listener as? AgileRTListener {
            agileRTListener = agListener
        }
        super.setListener(listener: listener)
    }
    
    override func connect() {
        subscribeToConnectionState()
        
        compositeDisposable = CompositeDisposable()
        if(compositeDisposable!.insert(bleDevice.establishConnection()
            .do(onNext: { connectedPer in
                print("PalBleSwift: PalAgileRT: connect: Connected")
                self.peripheral = connectedPer
                self.sendOnConnected()
            }, onDispose: {
                self.compositeDisposable = nil
            })
            .flatMapFirst { $0.observeValueUpdateAndSetNotification(for: PalAgileRTCharacteristic.message)}
            .subscribe(onNext: self.onNotification)) == nil) {
            print("PalBleSwift: PalAgileRT: connect: Error")
        }
    }
    
    func onNotification(char: Characteristic) {
        let bytes = char.value
        if(bytes == nil || bytes?.count == 0) {
            return;
        }
        
        if(bytes!.count == 20 || bytes!.count == 64 || bytes!.count == 128) {
            sendOnMemoryNotified(bytes: bytes!)
        } else if(bytes!.count == 1) {
            if(bytes![0] == 0x02) {
                initiliseDevice()
            } else if(bytes![0] == 0x01) {
                switchToLiveMode()
            }
        } else if(bytes!.count == 2) {
            switchToLiveMode()
        } else if(bytes!.count == 3) {
            sendOnAccelerationNotified(bytes: bytes!)
        } /*else if(bytes!.count == 5) {
            if(bytes![0] == 0x20) {
                
            }
        }*/
        else {
            print("PalBleSwift: PalAgileRT: onNotification: Unexpected notification: " + bytes!.toHexString())
        }
    }
    
    func initiliseDevice() {
        if(peripheral != nil) {
            let initiliser = Data([UInt8]([0x94, 0x17, 0x3C, 0x69, 0x01, 0x00, 0x00, 0x01]))
            if(compositeDisposable!.insert(peripheral!.writeValue(initiliser, for: PalAgileRTCharacteristic.command, type: .withResponse)
                .subscribe(onSuccess: onTimeWriteSuccess, onError: onError)) == nil) {
                print("PalBleSwift: PalAgileRT: initiliseDevice: Failed")
            }
        }
    }
    
    func switchToLiveMode() {
        sendModeCommand(modeCode: 0x13)
    }
    
    func sendModeCommand(modeCode: UInt8) {
        if(peripheral != nil) {
            let initiliser = Data([UInt8]([0x94, 0x17, 0x3C, 0x69, modeCode]))
            if(compositeDisposable!.insert(peripheral!.writeValue(initiliser, for: PalAgileRTCharacteristic.command, type: .withResponse)
                .subscribe(onSuccess: onTimeWriteSuccess, onError: onError)) == nil) {
                print("PalBleSwift: PalAgileRT: initiliseDevice: Failed")
            }
        }
    }
    
    func onTimeWriteSuccess(char: Characteristic) {
        print("PalBleSwift: PalAgileRT: onTimeWriteSuccess: " + (char.value?.toHexString() ?? "empty"))
    }
    
    func onError(error: Error) {
        print("PalBleSwift: PalAgileRT: onError: " + error.localizedDescription)
        dispose()
        throwError(error: error)
    }
    
    func sendOnMemoryNotified(bytes: Data) {
        if(agileRTListener != nil) {
            agileRTListener!.onMemoryNotified(packet: bytes)
        }
    }
    
    func sendOnAccelerationNotified(bytes: Data) {
        if(agileRTListener != nil) {
            agileRTListener!.onAccelerationNotified(
                x: Int(bytes[0] & 0xFF),
                y: Int(bytes[1] & 0xFF),
                z: Int(bytes[2] & 0xFF))
        }
    }
}
