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
    
    func decode() -> [TSStream] {

        let packets = preprocessData()
        var streams: [TSStream] = []
        for packet in packets {
            let byteConvertedPacket = Array(packet)
            
            let sync = byteConvertedPacket[0]
            let pidTemp: [UInt8] = [byteConvertedPacket[1],
                                    byteConvertedPacket[2]]
        
            let pid = (UInt16(pidTemp[0]) << 8) | UInt16(pidTemp[1])
            let flag = byteConvertedPacket[3]
            var header = TSHeader(syncBits: sync, pid: pid, flag: flag)
            header.parse()
           // print(header)
            if header.error
                || !header.hasPayloadData
                || header.pid == 0x1fff { continue } // pid 1fff null packet
            // switch pid
           // var pesStartCode: UInt32 = 0
            guard header.hasAfField && header.hasPayloadData else { continue }
            let pesStartIndex: Int = Int(byteConvertedPacket[4]) + 4 + 1
            
//            for i in pesStartIndex..<pesStartIndex + 3 {
//                print(byteConvertedPacket[i])
//            }
            var tsStream = TSStream()
  
            let streamId = byteConvertedPacket[(pesStartIndex + 3)]
            let streamLength = (UInt16(byteConvertedPacket[pesStartIndex + 4]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 5])
            let timeCodeFlag = (byteConvertedPacket[pesStartIndex + 7] >> 6) & 0x03
            let pesHeaderLength = byteConvertedPacket[pesStartIndex + 8]
            switch timeCodeFlag {
            case 2:
               let pts = UInt32((byteConvertedPacket[pesStartIndex + 9] & 0x0E) << 29)
                    | UInt32(byteConvertedPacket[pesStartIndex + 10] << 22)
                    | UInt32((byteConvertedPacket[pesStartIndex + 11] & 0xFE) << 14)
                    | UInt32(byteConvertedPacket[pesStartIndex + 12] << 7)
                    | UInt32(byteConvertedPacket[pesStartIndex + 13] >> 1)
                tsStream.pts = Int(pts)
            case 3:
                let pts = UInt32((byteConvertedPacket[pesStartIndex + 9] & 0x0E) << 29)
                    | UInt32(byteConvertedPacket[pesStartIndex + 10] << 22)
                    | UInt32((byteConvertedPacket[pesStartIndex + 11] & 0xFE) << 14)
                    | UInt32(byteConvertedPacket[pesStartIndex + 12] << 7)
                    | UInt32(byteConvertedPacket[pesStartIndex + 13] >> 1)
                
                let dts =
                    UInt32((byteConvertedPacket[pesStartIndex + 14] & 0x0E) << 29)
                    | UInt32(byteConvertedPacket[pesStartIndex + 15] << 22)
                    | UInt32((byteConvertedPacket[pesStartIndex + 16] & 0xFE) << 14)
                    | UInt32(byteConvertedPacket[pesStartIndex + 17] << 7)
                    | UInt32(byteConvertedPacket[pesStartIndex + 18] >> 1)
                tsStream.pts = Int(pts)
                tsStream.dts = Int(dts)
            default:
                assertionFailure("fail")
            }
            let actualDataIndex = Int(pesStartIndex) + 8 + Int(pesHeaderLength) + 1
            
            let actualData = Array(byteConvertedPacket[actualDataIndex...])
            tsStream.actualData = actualData
            
            streams.append(tsStream)
            
            
        }
        streams.sort()
        print(streams)
        return streams
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
        self.hasAfField = flag & 0x20 == 0x20 ? true : false
        self.hasPayloadData = flag & 0x10 == 0x10 ? true : false
        self.pid = pid & 0x1fff
    }
}

struct TSStream: Comparable {
    static func < (lhs: TSStream, rhs: TSStream) -> Bool {
        return lhs.pts < rhs.pts
    }
    
    var pts: Int = 0
    var dts: Int = 0
    var actualData: [UInt8] = []
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

