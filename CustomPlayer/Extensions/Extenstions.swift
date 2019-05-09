//
//  Extenstions.swift
//  MPEG-4Parser
//
//  Created by USER on 26/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation
import VideoToolbox


func assertDependOnMultiMediaValueStatus(_ status: OSStatus) {
    if status != 0 { assertionFailure("multimedia property error") }
}


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
    
    var addADTS: Data {
        
        let packetLength = self.count + 7
        let profile: UInt8 = 2
        let freqencyIndex: UInt8 = 4
        let channelConfiguration: UInt8 = 2
        var adtsHeader = [UInt8].init(repeating: 0, count: 7)
        
        adtsHeader[0] = 0xFF
        adtsHeader[1] = 0xF9
        adtsHeader[2] = (profile - 1) << 6 | (freqencyIndex << 2) | (channelConfiguration >> 2)
        adtsHeader[3] = (channelConfiguration & 3) << 6 | UInt8(packetLength >> 11)
        adtsHeader[4] = UInt8((packetLength & 0x7FF) >> 3)
        adtsHeader[5] = ((UInt8(packetLength & 7)) << 5) + 0x1F
        adtsHeader[6] = 0xFC
        
        var mutablePacket = adtsHeader.tohexNumbers.mergeToString.convertHexStringToData
        mutablePacket.append(self)
        
        return mutablePacket
        
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

extension Array where Element == CMSampleBuffer {
    mutating func copyNextSample() -> CMSampleBuffer? {
        if self.isEmpty {
            return nil
        }
        let item = self.first
        self.remove(at: 0)
        return item
    }
}

extension UInt8 {
    var toHexNumber: String {
        return String(format:"%02X", self)
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

extension Array where Element == Data {
    var toUInt8Array: [UInt8] {
        var array: [UInt8] = []
        self.forEach {
            array.append(contentsOf: $0)
        }
        return array
    }
    
    mutating func copyNextSample() -> Data? {
        if self.isEmpty {
            return nil
        }
        let item = self.first
        self.remove(at: 0)
        return item
    }
    
    
}

extension Container {
    
    var isParent: Bool {
        if type == .moov || type == .trak || type == .mdia || type == .minf
            || type == .dinf || type == .stbl || type == .edts || type == .udta {
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
