//
//  DaySummary.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 17/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

@objc public class DaySummary: NSObject {
    private var dayOfWeek: Int
    private var dateStr: String
    private var steps: Int
    private var upright: Int
    private var sedentary: Int
    private var sedentaryPercentage: Int
    private var valid: Bool
    
    public init(dateStr: String, dayOfWeek: Int, steps: Int, upright: Int, sedentary: Int) {
        self.dateStr = dateStr
        self.dayOfWeek = dayOfWeek
        self.steps = steps
        self.upright = upright
        self.sedentary = sedentary
        self.sedentaryPercentage = 0
        
        valid = upright > 0 && upright < 86400	
        
        super.init()
    }
    
    
    public func setDate(dateStr: String) {
        self.dateStr = dateStr
    }
    @objc public func getDate() -> String {
        return dateStr
    }
    
    public func setDayOfWeek(dayIndex: Int) {
        self.dayOfWeek = dayIndex
    }
    @objc public func getDayOfWeek() -> Int {
        return dayOfWeek
    }
    
    public func setSteps(steps: Int) {
        self.steps = steps
    }
    @objc public func getSteps() -> Int {
        return steps
    }
    
    public func setUpright(upright: Int) {
        self.upright = upright
    }
    @objc public func getUpright() -> Int {
        return upright
    }
    @objc public func getUprightTimeInMinutes() -> Int {
        return upright / 60
    }
    
    public func setSedentary(sedentary: Int) {
        self.sedentary = sedentary
    }
    @objc public func getSedentary() -> Int {
        return sedentary
    }
    @objc public func getSedentaryTimeInMinutes() -> Int {
        return sedentary / 60
    }
    
    public func setSedentaryPercentage(percentage: Int) {
        self.sedentaryPercentage = percentage
    }
    @objc public func getSedentaryPercentage() -> Int {
        return sedentaryPercentage
    }
    
    public func setValid(valid: Bool) {
        self.valid = valid
    }
    @objc public func isValid() -> Bool {
        return valid
    }
}
