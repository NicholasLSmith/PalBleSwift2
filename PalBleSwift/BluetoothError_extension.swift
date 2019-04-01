//
//  BluetoothError_extension.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 19/03/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit

extension BluetoothError {
    func getReason() -> Int {
        switch self {
        case BluetoothError.scanInProgress:
            return 5
        case BluetoothError.destroyed:
            return 7
        case BluetoothError.bluetoothUnsupported:
            return 2
        case BluetoothError.bluetoothUnauthorized:
            return 3
        case BluetoothError.bluetoothPoweredOff:
            return 1
        case BluetoothError.bluetoothInUnknownState:
            return 7
        case BluetoothError.bluetoothResetting:
            return 7
        default:
            return Int.max
        }
    }
}
