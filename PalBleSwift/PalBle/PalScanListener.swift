//
//  ScanListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol PalScanListener : PalListener {
    func onScanResultsChanged(device: PalDevice)
    func onScanTimeOut()
    
    func onScanError(error: Error)
}
