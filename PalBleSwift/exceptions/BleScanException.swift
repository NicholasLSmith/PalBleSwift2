//
//  BleScanException.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 20/03/2019.
//  Copyright © 2019 PAL Technologies Ltd. All rights reserved.
//

import Foundation
import RxBluetoothKit

@objc public class BleScanException: NSObject {
    let message: String
    let reason: Int

    @objc public init(message: String, reason: Int) {
        self.message = message
        self.reason = reason
    }
    
    @objc public func getReason() -> Int {
        return reason
    }
}
