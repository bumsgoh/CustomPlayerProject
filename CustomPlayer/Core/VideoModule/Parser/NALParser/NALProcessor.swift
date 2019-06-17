//
//  NALParser.swift
//  CustomPlayer
//
//  Created by bumslap on 10/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import CoreMedia

class NALProcessor {
    weak var delegate: MultiMediaVideoTypeDecoderDelegate?
    private var sps: [UInt8] = []
    private var pps: [UInt8] = []
    private var pts: [CMSampleTimingInfo]?
    private lazy var h264Decoder: H264Decoder = {
        let decoder = H264Decoder()
        decoder.videoDecoderDelegate = delegate
        return decoder
    }()
    private let taskManager: TaskManager
    
    init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }
    
    func setMetaData(sps: [UInt8], pps: [UInt8]) {
        self.sps = sps
        self.pps = pps
    }
    
    func process(frames: [UInt8], type: NALFormat, pts: [CMSampleTimingInfo], sizeArray: [Int] = []) {
        self.pts = pts
        var startCode: [UInt8] = []
        
        if Array(frames[0...3]) == VideoCodingConstant.startCodeAType {
            startCode = VideoCodingConstant.startCodeAType
        } else if Array(frames[0...2]) == VideoCodingConstant.startCodeBType {
            startCode = VideoCodingConstant.startCodeBType
        }
        
        var mutableFrames = frames
        var index = startCode.count
        var startCodeFlag = false

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
                             self.processNAL(nal: nal, type: .annexB)
                           // nalus.append(nalu)
                            
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
                
                
               processNAL(nal: nal, type: .annexB)
              //  nalus.append(nalu)
                
                if Array(mutableFrames[0..<3]) == VideoCodingConstant.startCodeBType {
                    index = VideoCodingConstant.startCodeBType.count
                    startCodeFlag = true
                } else {
                    index = VideoCodingConstant.startCodeAType.count
                    startCodeFlag = false
                }
            }

        case .avcc:
            var count = 0
          
            self.h264Decoder.decode(nal: NALUnit(type: .sps, payload: sps))
            self.h264Decoder.decode(nal: NALUnit(type: .pps, payload: pps))
            while true {
                if mutableFrames.isEmpty { break }
                let nal = Array(mutableFrames[0..<sizeArray[count]])
                processNAL(nal: nal, type: .avcc)
                //nalus.append(nalu)
                mutableFrames.removeSubrange(0..<sizeArray[count])
                count += 1
            }
           
    }
    }
        
        
        private func processNAL(nal: [UInt8], type: NALFormat) {
            let startCodeSize = 4
            var packet = nal
            if type == .annexB {
                var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
                memcpy(&packet, &lengthOfNAL, startCodeSize)
            }
            let nalType = packet[4] & 0x1F
            
            switch nalType {
            case NALType.idr.rawValue:
                guard let pts = self.pts?.removeFirst() else { break }
                let task = DispatchWorkItem {
                    self.h264Decoder.decode(nal: NALUnit(type: .idr, payload: packet), pts: pts)
                }
                taskManager.add(task: task)
                
            case NALType.slice.rawValue:
                guard let pts = self.pts?.removeFirst() else { break }
                let task = DispatchWorkItem {
                    self.h264Decoder.decode(nal: NALUnit(type: .slice, payload: packet), pts: pts)
                }
                taskManager.add(task: task)
             
            case NALType.sps.rawValue:
                let task = DispatchWorkItem {
                    self.h264Decoder.decode(nal: NALUnit(type: .sps, payload: Array(packet[startCodeSize..<packet.count])))
                }
                taskManager.add(task: task)
                
            case NALType.pps.rawValue:
                let task = DispatchWorkItem {
                    self.h264Decoder.decode(nal: NALUnit(type: .pps, payload: Array(packet[startCodeSize..<packet.count])))
                }
                taskManager.add(task: task)
                
            case NALType.aud.rawValue:
                break
              //  return NALUnit(type: .aud, payload: packet)
                
            case NALType.sei.rawValue:
                break
                //return NALUnit(type: .sei, payload: packet)
                
            default:
                break
               // return NALUnit(type: .unspecified, payload: [])
            }
        }
}

enum NALFormat {
    case annexB
    case avcc
}
