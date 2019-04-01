//
//  ConnectListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 12/09/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol ConnectListener : PalListener {
    func onDeviceFound()
    func onConnectTimeout()
    func onConnectError(connectionException: BleScanException)
}
