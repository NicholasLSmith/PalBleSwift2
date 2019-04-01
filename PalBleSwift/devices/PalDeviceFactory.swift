//
//  PalDeviceFactory.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit

public class PalDeviceFactory {
    public static func getDevice(scanResult : ScannedPeripheral) -> PalDevice? {
        if let name = scanResult.peripheral.name {
            if(name == "AgileRT") {
                return nil
            }
            if(name == "Activator") {
                let msd = scanResult.advertisementData.manufacturerData
                if(msd == nil || msd!.count < 8) {
                    return nil
                }
                if(msd![8] % 0xFF > 0) {
                    return PalActivatorV2(scanResult: scanResult)
                }
                return PalActivatorV1(scanResult: scanResult)
            }
            if(name == "Agile") {
                return nil
            }
        }
        return nil
    }
}
