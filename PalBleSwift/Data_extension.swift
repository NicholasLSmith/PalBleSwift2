//
//  Data_extension.swift
//  PalBleSwift
//
//  Created by Nicholas Smith on 04/10/2018.
//  Copyright © 2018 PAL Technologies Ltd. All rights reserved.
//

import Foundation

extension Data {
    
    var hexadecimalString: String {
        return self.reduce("") { (result, byte) in
            result + String(format: "%02X", byte)
        }
    }
    
    var base64UrlString: String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            + "\n"
            //.replacingOccurrences(of: "=", with: "")
    }
    
    // Return Data represented by this hexadecimal string
    static func fromHexString(string: String) -> Data {
        var data = Data(capacity: string.count / 2)
        
        let regex = try? NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex?.enumerateMatches(in: string, options: [], range: NSMakeRange(0, string.count)) { match, _, _ in
            if let match = match {
                let byteString = (string as NSString).substring(with: match.range)
                if var num = UInt8(byteString, radix: 16) {
                    data.append(&num, count: 1)
                }
            }
        }
        
        return data
    }
    
    static func fromBase64UrlString(base64String: String) -> Data? {
        let string = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "\n", with: "")
        /*while string.count % 4 != 0 {
            string = string.appending("=")
        }*/
        
        return Data(base64Encoded: string)
    }
}
