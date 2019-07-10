//
//  DataTransformer.swift
//  CustomPlayer
//
//  Created by bumslap on 10/07/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol DataTransformer {
    
    func convertToInt(target: Data) -> Int
    func convertToString(target: Data) -> String
    
}

extension DataTransformer {
    func convertToInt(target: Data) -> Int {
        var uIntArray: [UInt8] = []
        
//        self.forEach {
//            uIntArray.append($0)
//        }
        return uIntArray.tohexNumbers.toDecimalValue
    }
    
    func convertToString(target: Data) -> String {
        guard let convertedString = String(data: target, encoding: .utf8) else {
            return ""
        }
        return convertedString
    }
}
