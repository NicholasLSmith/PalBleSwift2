//
//  AgileRTListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 06/06/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol AgileRTListener: DeviceListener {
    func onAccelerationNotified(x: Int, y: Int, z: Int);
    func onMagnetometerNotified(bytes: Data);
    func onMemoryNotified(packet: Data);
    func onMemoryStarted(pagesToTransfer: Int);
    func onMemoryFinished(pagesTransfered: Int);
}
