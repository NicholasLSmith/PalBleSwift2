//
//  PalActivatorV1.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 16/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit
import CoreBluetooth

enum PalActivatorV1Characteristic: String, CharacteristicIdentifier {
    case mode =         "46e79001-f545-430c-b11f-54697f3103f4"
    case command =      "46e79002-f545-430c-b11f-54697f3103f4"
    case message =      "46e79003-f545-430c-b11f-54697f3103f4"
    
    case params =       "46e73001-f545-430c-b11f-54697f3103f4"
    
    case daily =        "46e73101-f545-430c-b11f-54697f3103f4"
    
    case sedPercent =   "46e73201-f545-430c-b11f-54697f3103f4"
    case steps =        "46e73202-f545-430c-b11f-54697f3103f4"
    case upright =      "46e73203-f545-430c-b11f-54697f3103f4"
    case sedentary =    "46e73204-f545-430c-b11f-54697f3103f4"
    
    case time =         "46e73301-f545-430c-b11f-54697f3103f4"
    
    case key =          "46e73401-f545-430c-b11f-54697f3103f4"
    case salt =         "46e73402-f545-430c-b11f-54697f3103f4"
    
    case req =          "46e73501-f545-430c-b11f-54697f3103f4"
    case data =         "46e73502-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    //Service to which characteristic belongs
    var service: ServiceIdentifier {
        switch self {
        case .mode, .command, .message:
            return PalActivatorV1Service.settings
        case .params:
            return PalActivatorV1Service.params
        case .daily:
            return PalActivatorV1Service.daily
        case .sedPercent, .steps, .upright, .sedentary:
            return PalActivatorV1Service.week
        case .time:
            return PalActivatorV1Service.time
        case .key, .salt:
            return PalActivatorV1Service.encrypt
        case .req, .data:
            return PalActivatorV1Service.sector
        }
    }
}

enum PalActivatorV1Service: String, ServiceIdentifier {
    case settings = "46e79000-f545-430c-b11f-54697f3103f4"
    case params =   "46e73000-f545-430c-b11f-54697f3103f4"
    case daily =    "46e73100-f545-430c-b11f-54697f3103f4"
    case week =     "46e73200-f545-430c-b11f-54697f3103f4"
    case time =     "46e73300-f545-430c-b11f-54697f3103f4"
    case encrypt =  "46e73400-f545-430c-b11f-54697f3103f4"
    case sector =   "46e73500-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

@objc public class PalActivatorV1: PalActivator {
    static let PALBT_SETTINGS_MODE_CHARACTERISTIC_UUID =    UUID.init(uuidString: "46e79001-f545-430c-b11f-54697f3103f4")!
    static let PALBT_SETTINGS_COMMAND_CHARACTERISTIC_UUID = UUID.init(uuidString: "46e79002-f545-430c-b11f-54697f3103f4")!
    static let PALBT_SETTINGS_MESSAGE_CHARACTERISTIC_UUID = UUID.init(uuidString: "46e79003-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_PARAMS_CHARACTERISTIC_UUID =           UUID.init(uuidString: "46e73001-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_DAILY_CHARACTERISTIC_UUID =            UUID.init(uuidString: "46e73101-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_WEEK_SED_PERCENT_CHARACTERISTIC_UUID = UUID.init(uuidString: "46e73201-f545-430c-b11f-54697f3103f4")!
    static let PALBT_WEEK_STEPS_CHARACTERISTIC_UUID =       UUID.init(uuidString: "46e73202-f545-430c-b11f-54697f3103f4")!
    static let PALBT_WEEK_UP_TIME_CHARACTERISTIC_UUID =     UUID.init(uuidString: "46e73203-f545-430c-b11f-54697f3103f4")!
    static let PALBT_WEEK_SED_TIME_CHARACTERISTIC_UUID =    UUID.init(uuidString: "46e73204-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_TIME_CHARACTERISTIC_UUID =             UUID.init(uuidString: "46e73301-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_ENCRYPT_KEY_CHARACTERISTIC_UUID =      UUID.init(uuidString: "46e73401-f545-430c-b11f-54697f3103f4")!
    static let PALBT_ENCRYPT_SALT_CHARACTERISTIC_UUID =     UUID.init(uuidString: "46e73402-f545-430c-b11f-54697f3103f4")!
    
    static let PALBT_SECTOR_REQ_CHARACTERISTIC_UUID =       UUID.init(uuidString: "46e73501-f545-430c-b11f-54697f3103f4")!
    static let PALBT_SECTOR_DATA_CHARACTERISTIC_UUID =      UUID.init(uuidString: "46e73502-f545-430c-b11f-54697f3103f4")!
    
    
    public override init(scanResult: ScannedPeripheral) {
        print("PalActivatorV1: init")
        super.init(scanResult: scanResult)
    }
    
    override func connectToWake() {
        connectToWake(wakingCharacteristicIdentifier: PalActivatorV1Characteristic.mode)
    }
    
    override func encryptThenFetchAllData(key: Data) {
        encryptThenFetchAllData(key: key, characteristic: PalActivatorV1Characteristic.key)
    }
    
    override func fetchAllData() {
        //TODO
    }
    
    func finalDispose() {
        reconnectOnDisconnect = 0
        dispose()
    }
    
    /*
     override func getEncryptionCheckSingle() -> Single<Pair<Data, Data>> {
     return Single.zip()
     }
     
     override func getDataFetchSingle() -> Single<PalActivatorRawData> {
     }
     
     */
    
    
}
