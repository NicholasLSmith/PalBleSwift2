//
//  Identifiers.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 04/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import RxBluetoothKit
import CoreBluetooth

enum DeviceCharacteristic: String, CharacteristicIdentifier {
    
    // dfu
    case dfu =          "46e70001-f545-430c-b11f-54697f3103f4"
    // setup
    case setup =        "46e73001-f545-430c-b11f-54697f3103f4"
    // common
    case info =         "46e73101-f545-430c-b11f-54697f3103f4"
    case time =         "46e73102-f545-430c-b11f-54697f3103f4"
    case encryption =   "46e73103-f545-430c-b11f-54697f3103f4"
    case data =         "46e73104-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    //Service to which characteristic belongs
    var service: ServiceIdentifier {
        switch self {
        case .dfu:
            return DeviceService.dfu
        case .setup:
            return DeviceService.setup
        case .info, .time, .encryption, .data:
            return DeviceService.common
        }
    }
}

enum DeviceService: String, ServiceIdentifier {
    case dfu =      "46e70000-f545-430c-b11f-54697f3103f4"
    case setup =    "46e73000-f545-430c-b11f-54697f3103f4"
    case common =   "46e73100-f545-430c-b11f-54697f3103f4"
    
    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
}
