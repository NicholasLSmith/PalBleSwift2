//
//  ScanParameters.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 12/09/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public class ScanParameters: NSObject {
    @objc public static let ALL = 0
    @objc public static let ACTIVATOR = 1
    @objc public static let AGILE = 2
    @objc public static let AGILERT = 3
    @objc public static let LAM = 4
    
    @objc public var deviceFamily = ALL
    @objc public var scanTimeout = 15
    
    @objc public func getDeviceFamily() -> String? {
        switch (deviceFamily) {
        case ScanParameters.ACTIVATOR:
            return "Activator"
        case ScanParameters.AGILE:
            return "Agile"
        case ScanParameters.AGILERT:
            return "AgileRT"
        case ScanParameters.LAM:
            return "LAM8"
        default:
            return nil
        }
    }
    
    @objc public var serialList = [String]()
}
