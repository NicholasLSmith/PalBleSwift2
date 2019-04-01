//
//  ActivatorListener.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 01/08/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public protocol ActivatorListener: DeviceListener {
    func onWaking()
    func onWoken()
    func onSummariesRetrieved();
    func onNewEncryptionKeyNeeded();
    func onExistingEncryptionKeyNeeded();
    
    func onHapticSet(success: Bool)
    func onSleep()
    
    func onDataDownload(bytes: Data)
    func onDataError()
    func onDataDone()
}
