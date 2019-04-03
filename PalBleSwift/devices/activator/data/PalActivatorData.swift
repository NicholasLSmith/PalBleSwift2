//
//  PalActivatorData.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 17/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public class PalActivatorData: NSObject {
    private var serial: String = ""
    private var firmwareVersion: Int = 0
    private var bootCount: Int = 0
    
    private var currentDeviceSecondsSincePalTime: UInt = 0
    private var currentPhoneSecondsSincePalTime: UInt = 0
    private var currentDeviceTimeZone: Int = 0
    private var currentPhoneTimeZone: Int = 0
    private var currentBattery: Int = 0
    private var currentPage: Int = 0
    
    private var currentHourSedentaryPercentage: Int = 0
    private var currentDaySedentartyPercentage: Int = 0
    
    private var daySummaries: [DaySummary] = [DaySummary]()
    private var sedentaryReminder: Int = 0
    private var accelerometerResets: Int = 0
    private var memoryFull: Bool = false
    private var batteryHealth: Int = 0
    private var stoppedDeviceSecondsSincePalTime: UInt = 0
    
    
    public override init() {
        super.init()
    }
    
    public func setAdvertisment(serial: String, firmware: Int, bootCount: Int) {
        self.serial = serial
        self.firmwareVersion = firmware
        self.bootCount = bootCount
    }
    
    public func setParameters(parameter: Data) {
        currentDeviceSecondsSincePalTime = UInt(parameter[0] & 0xFF)
            + (UInt(parameter[1] & 0xFF) << 8)
            + (UInt(parameter[2] & 0xFF) << 16)
            + (UInt(parameter[3] & 0xFF) << 24)
        currentDeviceSecondsSincePalTime += UInt(parameter[4] & 0xFF)
            + (UInt(parameter[5] & 0xFF) << 8)
            + (UInt(parameter[6] & 0xFF) << 16)
            + (UInt(parameter[7] & 0xFF) << 24)
        currentDeviceTimeZone = Int(parameter[8])
        
        currentBattery = Int(parameter[9] & 0xFF)
        
        currentPage = Int(parameter[10] & 0xFF)
            + (Int(parameter[11] & 0xFF) << 8)
            + (Int(parameter[12] & 0xFF) << 16)
            + (Int(parameter[13] & 0xFF) << 24)
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier:"UTC")
        formatter.dateFormat = "yyyyMMdd"
        let palDate = formatter.date(from: "20170101")
        currentPhoneSecondsSincePalTime = UInt(-(palDate!.timeIntervalSinceNow))
        currentPhoneTimeZone = TimeZone.current.secondsFromGMT() / 900
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd hh:mm:ss"
        print("PalBleSwift: PalActivatorData: setParameters: Device time: " + df.string(from: getCurrentDeviceDate()))
    }
    
    public func setData(daily: Data, sedentaryPer: Data, step: Data, upright: Data, sedentary: Data) {
        currentHourSedentaryPercentage = Int(daily[4] & 0xFF)
        currentDaySedentartyPercentage = Int(daily[5] & 0xFF)
        sedentaryReminder = Int(daily[8] & 0xFF)
        accelerometerResets = Int(daily[9] & 0xFF)
        memoryFull = (daily[10] & 0xFF) == 0x01 ? true : false
        batteryHealth = Int(daily[11] & 0xFF)
        stoppedDeviceSecondsSincePalTime = UInt(daily[12] & 0xFF)
            + (UInt(daily[13] & 0xFF) << 8)
            + (UInt(daily[14] & 0xFF) << 16)
            + (UInt(daily[15] & 0xFF) << 24)
        
        var date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyy-MM-dd")
        
        daySummaries.append(DaySummary(dateStr: dateFormatter.string(from: date),
                                       dayOfWeek: Calendar.current.component(.weekday, from: date),
                                       steps: 256 * Int(daily[2] & 0xFF) + Int(daily[3] & 0xFF),
                                       upright: 256 * Int(daily[0] & 0xFF) + Int(daily[1] & 0xFF),
                                       sedentary: 256 * Int(daily[6] & 0xFF) + Int(daily[7] & 0xFF)))
        
        for i in 1...6 {
            let up = 60 * (256 * Int(upright[2*i + 1] & 0xFF) + Int(upright[2*i] & 0xFF))
            let sed = 60 * (256 * Int(sedentary[2*i + 1] & 0xFF) + Int(sedentary[2*i] & 0xFF))
            let sedPer = Int(sedentaryPer[i] & 0xFF)
            if(up + sed > 86400 || sedPer > 100) {
                break;
            }
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            daySummaries.append(DaySummary(dateStr: dateFormatter.string(from: date),
                                        dayOfWeek: Calendar.current.component(.weekday, from: date),
                                        steps: 256 * Int(step[2*i + 1] & 0xFF) + Int(step[2*i] & 0xFF),
                                        upright: up,
                                        sedentary: sed))
        }
    }
    
    
    @objc public func getCurrentDeviceSecondsSincePalTime() -> UInt {
        return currentDeviceSecondsSincePalTime
    }
    
    @objc public func getCurrentDeviceDate() -> Date {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier:"UTC")
        formatter.dateFormat = "yyyyMMdd"
        let palDate = formatter.date(from: "20170101")
        
        if(currentDeviceSecondsSincePalTime <= Int.max) {
                return Calendar.current.date(byAdding: .second, value: Int(currentDeviceSecondsSincePalTime), to: palDate!)!
        } else {
            let date = Calendar.current.date(byAdding: .second, value: Int.max, to: palDate!)!
            return Calendar.current.date(byAdding: .second, value: Int(currentDeviceSecondsSincePalTime - UInt(Int.max)), to: date)!
        }
    }
    
    @objc public func getCurrentDeviceDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyy-MM-dd")
        return dateFormatter.string(from: getCurrentDeviceDate())
    }
    
    @objc public func getCurrentDeviceTimeZone() -> Int {
        return currentDeviceTimeZone
    }
    
    
    @objc public func getCurrentPhoneSecondsSincePalTime() -> UInt {
        return currentPhoneSecondsSincePalTime
    }
    
    @objc public func getCurrentPhoneTimeZone() -> Int {
        return currentPhoneTimeZone
    }
    
    
    @objc public func getCurrentBattery() -> Int {
        return currentBattery
    }
    
    @objc public func getCurrentPage() -> Int {
        return currentPage
    }
    
    @objc public func getCurrentHourSedentaryPercentage() -> Int {
        return currentHourSedentaryPercentage
    }
    
    @objc public func getCurrentDaySedentaryPercentage() -> Int {
        return currentDaySedentartyPercentage
    }
    
    @objc public func getDaySummaries() -> [DaySummary] {
        return daySummaries
    }
    
    
    @objc public func getSerial() -> String {
        return serial
    }
    
    @objc public func getFirmwareVersion() -> Int {
        return firmwareVersion
    }
    
    @objc public func getBootCount() -> Int {
        return bootCount
    }
    
    
    @objc public func getSedentaryReminder() -> Int {
        return sedentaryReminder
    }
    
    @objc public func getAccelerometerResets() -> Int {
        return accelerometerResets
    }
    
    @objc public func isMemoryFull() -> Bool {
        return memoryFull
    }
    
    @objc public func getBatteryHealth() -> Int {
        return batteryHealth
    }
    
    @objc public func getStoppedDeviceSecondsSincePalTime() -> UInt {
        return stoppedDeviceSecondsSincePalTime
    }
}


















