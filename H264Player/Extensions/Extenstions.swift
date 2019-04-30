//
//  Extenstions.swift
//  MPEG-4Parser
//
//  Created by USER on 26/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

extension Data {
    var convertToInt: Int {
        var uIntArray: [UInt8] = []
        self.forEach {
            uIntArray.append($0)
        }
        return uIntArray.tohexNumbers.toDecimalValue
    }
    
    func slice(in sizes: [Int]) -> [Data] {
        
        var offset = 0
        var slicedData: [Data] = []
        
        for size in sizes {
            if self.count > (offset + size) {
                slicedData.append(self.subdata(in: offset..<(offset + size)))
                offset += size
            } else {
                break
            }
        }
        return slicedData
    }
    
    var convertToString: String {
        guard let convertedString = String(data: self, encoding: .utf8) else {
            return ""
        }
        return convertedString
    }
}

extension String {
    var convertHexStringToData: Data {
        var hexString = self
        var data = Data()
        while hexString.count > 0 {
            let subIndex = hexString.index(hexString.startIndex, offsetBy: 2)
            let slicedString = String(hexString[..<subIndex])
            hexString = String(hexString[subIndex...])
            var tempStorageForUInt8: UInt32 = 0
            Scanner(string: slicedString).scanHexInt32(&tempStorageForUInt8)
            var convertedNumber = UInt8(tempStorageForUInt8)
            data.append(&convertedNumber, count: 1)
        }
        return data
    }
}

extension Array where Element == UInt8 {
    mutating func flush() {
        self.removeAll()
    }
    
    var tohexNumbers: [String] {
        let hexNumbers = self.map {
            $0.toHexNumber
        }
        return hexNumbers
    }
}

extension UInt8 {
    var toHexNumber: String {
        return String(self, radix: 16, uppercase: false)
    }
}

extension InputStream {
    func readByHexNumber(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        
        return self.read(buffer, maxLength: len)
    }
}

extension Array where Element == String {
    var mergeToString: String {
        let mergedString = self.joined()
        return mergedString
    }
    
    var toDecimalValue: Int {
        guard let hexNumber = Int(self.mergeToString, radix: 16) else {
            return 0
        }
        return hexNumber
    }
}

extension Container {
    var isParent: Bool {
        if type == .moov || type == .trak || type == .mdia || type == .minf
            || type == .dinf || type == .stbl || type == .udta {
            return true
        } else {
            return false
        }
    }
    
    var isHeader: Bool {
        if type == .ftyp || type == .free || type == .mvhd || type == .tkhd || type == . edts
            || type == .mdhd || type == .stbl || type == .hdlr || type == .vmhd
            || type == .smhd {
            
            return true
        } else {
            return false
        }
    }
}

extension FileHandle {
    func hasMoreData() -> Bool {
        let position = offsetInFile
        let length = seekToEndOfFile()
        if position < length {
            seek(toFileOffset: position)
            return true
        }
        else {
            return false
        }
    }
}
