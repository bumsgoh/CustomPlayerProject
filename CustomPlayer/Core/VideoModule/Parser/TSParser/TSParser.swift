//
//  TSDecoder.swift
//  CustomPlayer
//
//  Created by USER on 15/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class TSParser {
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
            processedData.append(data)
            mutableTargetData = mutableTargetData.advanced(by: packetLength)
        }
        
        return processedData
    }
    
    func parse() -> [DataStream] {
        
        let packets = preprocessData()
        var streams: [DataStream] = []
        var currentLeadingVideoPacket: DataStream?
        var currentLeadingAudioPacket: DataStream?
        var videoPid: UInt16 = 0
        var audioPid: UInt16 = 0
        
        var videoStream: DataStream = DataStream()
        var audioStream: DataStream = DataStream()
        videoStream.type = .video
        audioStream.type = .audio
        

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
                || header.pid == 0x1fff
                || header.pid == 0 { continue } // pid 1fff null packet, if 0 PAT Packet

            let pesStartIndex: Int = header.hasAfField ? Int(byteConvertedPacket[4]) + 4 + 1 : 4
        
            
            
            if !header.payloadUnitStartIndicator {
                if header.pid == videoPid {
                    let actualData = Array(byteConvertedPacket[pesStartIndex...])
                   // currentLeadingVideoPacket?.actualData.append(contentsOf: actualData)
                    videoStream.actualData.append(contentsOf: actualData)
                } else {
                    let actualData = Array(byteConvertedPacket[pesStartIndex...])
                   // currentLeadingAudioPacket?.actualData.append(contentsOf: actualData)
                    audioStream.actualData.append(contentsOf: actualData)
                }
                continue
            } else {
                let streamId = byteConvertedPacket[(pesStartIndex + 3)]
                let streamLength = (UInt16(byteConvertedPacket[pesStartIndex + 4]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 5])
                let timeCodeFlag = (byteConvertedPacket[pesStartIndex + 7] >> 6) & 0x03
                let pesHeaderLength = byteConvertedPacket[pesStartIndex + 8]

                switch streamId {
                case 224:
                    currentLeadingVideoPacket = nil
                    currentLeadingVideoPacket = DataStream()
                    currentLeadingVideoPacket?.type = .video
                    videoPid = header.pid
                    
                    switch timeCodeFlag {
                    case 2:
                        let high = ((UInt16(byteConvertedPacket[pesStartIndex + 10]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 11])) >> 1
                        let low = ((UInt16(byteConvertedPacket[pesStartIndex + 12]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 13])) >> 1
                        currentLeadingVideoPacket?.pts[0] = Int(UInt32(high) << 15 | UInt32(low))
                    case 3:
                        let high = ((UInt16(byteConvertedPacket[pesStartIndex + 10]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 11])) >> 1
                        let low = ((UInt16(byteConvertedPacket[pesStartIndex + 12]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 13])) >> 1
                        currentLeadingVideoPacket?.pts[0] = Int(UInt32(high) << 15 | UInt32(low))
                        
                        let dtsHigh = ((UInt16(byteConvertedPacket[pesStartIndex + 15]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 16])) >> 1
                        let dtsLow = ((UInt16(byteConvertedPacket[pesStartIndex + 17]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 18])) >> 1
                        currentLeadingVideoPacket?.dts[0] = Int(UInt32(dtsHigh) << 15 | UInt32(dtsLow))
                    //  print("pts: \(tsStream.pts)")
                    case 0:
                        currentLeadingVideoPacket?.pts[0] = 0
                        currentLeadingVideoPacket?.dts[0] = 0
                    default:
                        assertionFailure("fail")
                    }
                    guard let currentPacket = currentLeadingVideoPacket else {
                        return []
                    }
                    let actualDataIndex = Int(pesStartIndex) + 8 + Int(pesHeaderLength) + 1
                    let actualData = Array(byteConvertedPacket[actualDataIndex...])
                   // currentLeadingVideoPacket?.actualData = actualData
                    videoStream.actualData.append(contentsOf: actualData)
                    videoStream.pts.append(currentPacket.pts[0])
                    videoStream.dts.append(currentPacket.dts[0])
                  //  streams.append(videoStream)
                    
                case 192:
                    currentLeadingAudioPacket = DataStream()
                    currentLeadingAudioPacket?.type = .audio
                    audioPid = header.pid
                    
                    switch timeCodeFlag {
                    case 2:
                        let high = ((UInt16(byteConvertedPacket[pesStartIndex + 10]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 11])) >> 1
                        let low = ((UInt16(byteConvertedPacket[pesStartIndex + 12]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 13])) >> 1
                        currentLeadingAudioPacket?.pts[0] = Int(UInt32(high) << 15 | UInt32(low))
                    case 3:
                        let high = ((UInt16(byteConvertedPacket[pesStartIndex + 10]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 11])) >> 1
                        let low = ((UInt16(byteConvertedPacket[pesStartIndex + 12]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 13])) >> 1
                        currentLeadingAudioPacket?.pts[0] = Int(UInt32(high) << 15 | UInt32(low))
                        
                        let dtsHigh = ((UInt16(byteConvertedPacket[pesStartIndex + 15]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 16])) >> 1
                        let dtsLow = ((UInt16(byteConvertedPacket[pesStartIndex + 17]) << 8) | UInt16(byteConvertedPacket[pesStartIndex + 18])) >> 1
                        currentLeadingAudioPacket?.dts[0] = Int(UInt32(dtsHigh) << 15 | UInt32(dtsLow))
                    //  print("pts: \(tsStream.pts)")
                    case 0:
                        currentLeadingAudioPacket?.pts[0] = 0
                        currentLeadingAudioPacket?.dts[0] = 0
                    default:
                        assertionFailure("fail")
                    }
                    guard let currentPacket = currentLeadingAudioPacket else {
                        return []
                    }
                    let actualDataIndex = Int(pesStartIndex) + 8 + Int(pesHeaderLength) + 1
                    let actualData = Array(byteConvertedPacket[actualDataIndex...])
                   // currentLeadingVideoPacket?.actualData = actualData
                    audioStream.actualData.append(contentsOf: actualData)
                    audioStream.pts.append(currentPacket.pts[0])
                    audioStream.dts.append(currentPacket.dts[0])
                  //  streams.append(audioStream)
                default:
                    continue
                }
            }
        }
        streams.append(audioStream)
        streams.append(videoStream)
        
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


