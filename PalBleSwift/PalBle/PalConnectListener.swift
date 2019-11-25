//
//  ConnectListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 12/09/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol PalConnectListener : PalListener {
    func onDeviceFound(device: PalDevice)
    func onConnectTimeout()
    
    func onConnectError(error: Error)
}
