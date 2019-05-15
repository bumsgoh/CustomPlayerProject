//
//  TSDecoder.swift
//  CustomPlayer
//
//  Created by USER on 15/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class TSDecoder {
    private let packetLength = 188
    private let headerLength = 4
    private let targetData: Data
    
    init(target: Data) {
        self.targetData = target
    }
    
    
    private func preprocessData() -> [Data] {
        let numberOfPackets = targetData.count / packetLength
        var mutableTargetData = targetData
        var processedData: [Data] = []
        
        for _ in 0..<(numberOfPackets - 1) {
            let data = mutableTargetData.subdata(in: 0..<packetLength)
            let advancedData = mutableTargetData
            processedData.append(data)
            mutableTargetData = mutableTargetData.advanced(by: packetLength)
        }
        
        return processedData
    }
    
    func decode() {
        let packets = preprocessData()
        for packet in packets {
            let byteConvertedPacket = Array(packet)
            
            let sync = byteConvertedPacket[0]
            let pidTemp: [UInt8] = [byteConvertedPacket[1],
                                    byteConvertedPacket[2]]
        
            let pid = (UInt16(pidTemp[0]) << 8) | UInt16(pidTemp[1])
            let flag = byteConvertedPacket[3]
            var header = TSHeader(syncBits: sync, pid: pid, flag: flag)
            header.parse()
            
            if header.error
                || !header.hasPayloadData
                || header.pid == 0x1fff { continue } // pid 1fff null packet
            // switch pid
            
           
            
            
            
        }
        
    }
}

struct TSHeader {
    var syncBits: UInt8
    var pid: UInt16
    var flag: UInt8
    var error: Bool = false
    var payloadUnitStartIndicator: Bool = false
    var hasAfField: Bool = false
    var hasPayloadData:Bool = false
    init(syncBits: UInt8, pid: UInt16, flag: UInt8) {
        self.syncBits = syncBits
        self.pid = pid
        self.flag = flag
    }
    mutating func parse() {
        self.error = pid & 0x8000 == 0x8000 ? true : false
        self.payloadUnitStartIndicator = pid & 0x4000 == 0x4000 ? true : false
        print("pid: \(pid)")
        self.hasAfField = flag & 0x20 == 0x20 ? true : false
        self.hasPayloadData = flag & 0x10 == 0x10 ? true : false
        self.pid = pid & 0x1fff
    }
}

struct TS {
    enum MediaType {
    
        case MPEG2Video
        case H264Video
        case VC1
        case AC3
        case MPEG2Audio
        case LPCM
        case DTS
        case nonEs
    }
    
    static let typeDictinary: [UInt8: MediaType] = [
        0x01: MediaType.MPEG2Video,
        0x02: MediaType.MPEG2Video,
        0x80: MediaType.MPEG2Video,
        0x1b: MediaType.H264Video,
        0xea: MediaType.VC1,
        0x81: MediaType.AC3,
        0x06: MediaType.AC3,
        0x83: MediaType.AC3,
        0x03: MediaType.MPEG2Audio,
        0x04: MediaType.MPEG2Audio,
        0x80: MediaType.LPCM,
        0x82: MediaType.DTS,
        0x86: MediaType.DTS,
        0x8a: MediaType.DTS,
        0xff: MediaType.nonEs
    ]
    
}

struct Packet {
    var header: TSHeader
    var PES: Data
    
}

