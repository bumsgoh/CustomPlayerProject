//
//  NALParser.swift
//  CustomPlayer
//
//  Created by bumslap on 10/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class NALParser {
    private let sps: [UInt8]
    private let pps: [UInt8]
    
    init(sps: [UInt8] = [], pps: [UInt8] = []) {
        self.sps = sps
        self.pps = pps
    }
    
    func parse(frames: [UInt8], type: NALFormat, sizeArray: [Int] = []) -> [NALUnit] {
        var startCode: [UInt8] = []
        
        if Array(frames[0...3]) == VideoCodingConstant.startCodeAType {
            startCode = VideoCodingConstant.startCodeAType
        } else if Array(frames[0...2]) == VideoCodingConstant.startCodeBType {
            startCode = VideoCodingConstant.startCodeBType
        }
        
        var mutableFrames = frames
        var index = startCode.count
        var startCodeFlag = false

        var nalus: [NALUnit] = []
        //   decodeQueue.async { [weak self] in
        //      guard let self = self else { return}
        switch type {
        case .annexB:
            var hasDone = false
            while !hasDone {
                //  if isBufferFull { continue }
                while Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeBType.count)])
                    != VideoCodingConstant.startCodeBType
                    && Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeAType.count)]) != VideoCodingConstant.startCodeAType {
                        
                        if index + VideoCodingConstant.startCodeAType.count > mutableFrames.count - 1
                            && !mutableFrames.isEmpty {
                            let nal = Array(mutableFrames[0...])
                            let nalu = self.processNAL(nal: nal, type: .annexB)
                            nalus.append(nalu)
                            hasDone = true
                            break
                        }
                        index += 1
                }
                
                var nal = Array(mutableFrames[0..<index])
                mutableFrames.removeSubrange(0..<index)
                
                if startCodeFlag {
                    nal.insert(0, at: 0)
                }
                
                
                let nalu =  processNAL(nal: nal, type: .annexB)
                nalus.append(nalu)
                
                if Array(mutableFrames[0..<3]) == VideoCodingConstant.startCodeBType {
                    index = VideoCodingConstant.startCodeBType.count
                    startCodeFlag = true
                } else {
                    index = VideoCodingConstant.startCodeAType.count
                    startCodeFlag = false
                }
            }
            return nalus
        case .avcc:
            var count = 0
            var nalus: [NALUnit] = [NALUnit(type: .sps, payload: sps) ,NALUnit(type: .pps, payload: pps) ]
            
            while true {
                if mutableFrames.isEmpty { break }
                let nal = Array(mutableFrames[0..<sizeArray[count]])
                let nalu = processNAL(nal: nal, type: .avcc)
                nalus.append(nalu)
                mutableFrames.removeSubrange(0..<sizeArray[count])
                count += 1
            }
            return nalus
    }
    }
        
        
        private func processNAL(nal: [UInt8], type: NALFormat) -> NALUnit {
            let startCodeSize = 4
            var packet = nal
            if type == .annexB {
                var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
                memcpy(&packet, &lengthOfNAL, startCodeSize)
            }
            let nalType = packet[4] & 0x1F
            
            switch nalType {
            case NALType.idr.rawValue:
                 return NALUnit(type: .idr, payload: packet)
                
            case NALType.slice.rawValue:
               return NALUnit(type: .slice, payload: packet)
                
            case NALType.sps.rawValue:
                return NALUnit(type: .sps, payload: Array(packet[startCodeSize..<packet.count]))
                
            case NALType.pps.rawValue:
                return NALUnit(type: .pps, payload: Array(packet[startCodeSize..<packet.count]))
                
            case NALType.aud.rawValue:
                return NALUnit(type: .aud, payload: packet)
                
            case NALType.sei.rawValue:
                return NALUnit(type: .sei, payload: packet)
                
            default:
                return NALUnit(type: .unspecified, payload: [])
            }
        }
}

enum NALFormat {
    case annexB
    case avcc
}
