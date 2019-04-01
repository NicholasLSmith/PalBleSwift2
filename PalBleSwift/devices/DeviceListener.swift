//
//  DeviceListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol DeviceListener {
    func onConnected(device: PalDevice)
    func onDisconnected()
    
    func onRetrying(triesRemaining: Int)
    
    func onInvalidEncryptionKey()
    func onDeviceError(error: Error)
    
    func onDfuEnabled(device: PalDevice)
}
