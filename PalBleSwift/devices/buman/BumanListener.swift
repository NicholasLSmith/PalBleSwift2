//
//  BumanListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 03/07/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol BumanListener: PalDeviceListener {
    func onSpike(z: Int);
}
