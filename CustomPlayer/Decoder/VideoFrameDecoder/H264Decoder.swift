//
//  VideoFrameDecoder.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

class H264Decoder {
    
    private let lockQueue = DispatchQueue(label: "com.bumslap.h264DecoderLock")
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    private var sps: [UInt8]?
    private var pps: [UInt8]?
    
    private var pictureCount = 0
    weak var videoDecoderDelegate: MultiMediaVideoTypeDecoderDelegate?
    
    private var frames: [UInt8]

    private var presentationTimestamps: [CMSampleTimingInfo]
    
    private lazy var startCode: [UInt8] = []
    
    private var callback: VTDecompressionOutputCallback = {(
        decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVBuffer?,
        presentationTimeStamp: CMTime,
        duration: CMTime) in
        
        let decoder: H264Decoder = unsafeBitCast(decompressionOutputRefCon,
                                                 to: H264Decoder.self)
        guard let decodedBuffer = imageBuffer else { return }
        
        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid
        )
        
        var formatDescription: CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: decodedBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        var decodedSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: decodedBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &decodedSampleBuffer
        )
        
        decoder.videoDecoderDelegate?.prepareToDisplay(with: decodedSampleBuffer!)
    }
  

    init(frames: [UInt8], presentationTimestamps: [CMSampleTimingInfo]) {
        self.frames = frames
        self.presentationTimestamps = presentationTimestamps
        
        
        if Array(frames[0...3]) == VideoCodingConstant.startCodeAType {
            self.startCode = VideoCodingConstant.startCodeAType
        } else if Array(frames[0...2]) == VideoCodingConstant.startCodeBType {
            self.startCode = VideoCodingConstant.startCodeBType
        } else {
            return
        }
    }
    
    func decode() {
        guard let nalu = makeNALUnits() else { return }
        
        
        for nal in nalu {
            //print("nalu: \(nal)")
            var packet = nal
          //  print(packet)
           // ["00", "00", "00", "01", "09, 240"00", "00", "00", "01", "06", "05", "11", "03", "87", "F4", "4E", "CD", "0A", "4B", "DC", "A1", "94", "3A", "C3", "D4", "9B", "17", "1F", "00", "80", "00",
            if Array(packet[0..<6]) == [0, 0, 0, 1, 9, 240] {
                packet = stripAUD(packet: packet)
                if packet.count < 2 { continue }
            }
         //   print(packet)
            analyzeNALAndDecode(packet: &packet)
            
        }
    }

    
    private func analyzeNALAndDecode(packet: inout [UInt8]) {
        //   print(videoPacket)
 //print(packet)
        let preservedPacket = packet
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
print("pack is: \(packet.tohexNumbers)")
        memcpy(&packet, &lengthOfNAL, 4)
        // change to Avcc format
        
  //      print("avcc is: \(packet.tohexNumbers)")
        let typeOfNAL = packet[4] & 0x1F
      // print("packet number \(packet[4].toHexNumber)")
       // print("t nal: \(typeOfNAL)")
        switch typeOfNAL {
        case TypeOfNAL.idr.rawValue, TypeOfNAL.bpFrame.rawValue:
            let timingInfo = presentationTimestamps[pictureCount]
            print(timingInfo)
            pictureCount += 1
            decodeVideoPacket(packet: packet, timingInfos: timingInfo)
        case TypeOfNAL.sps.rawValue:
            spsSize = packet.count - 4
            sps = Array(packet[4..<packet.count])
            updateDecompressionSession()
        case TypeOfNAL.pps.rawValue:
            ppsSize = packet.count - 4
            pps = Array(packet[4..<packet.count])
            updateDecompressionSession()
//        case TypeOfNAL.sei.rawValue:
//            let listOfNal = parseSEI(packet: preservedPacket)
//            guard let nalu = listOfNal else { break }
//            nalu.forEach {
//               // print($0.tohexNumbers)
//                var mutableData = $0
//                analyzeNALAndDecode(packet: &mutableData)
//            }
//
//
        default:
          
            break
        }
     //   print(pictureCount)
        
    }
    
    private func stripAUD(packet: [UInt8]) -> [UInt8]{
        var mutablePacket = packet
        mutablePacket.removeSubrange(0..<6)
  //      print(mutablePacket)
        if mutablePacket.isEmpty { return [] }
       // print(mutablePacket[0..<3])
        if Array(mutablePacket[0..<3]) == VideoCodingConstant.startCodeBType {
             mutablePacket.insert(0, at: 0)
        }
    //    print(mutablePacket)
        return mutablePacket
    }
    
    private func decodeVideoPacket(packet:[UInt8], timingInfos: CMSampleTimingInfo) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: packet)
        var blockBuffer: CMBlockBuffer?

        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: bufferPointer,
            blockLength: packet.count,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: packet.count,
            flags: 0,
            blockBufferOut: &blockBuffer) == kCMBlockBufferNoErr else {
                return
                
        }
        
        
        var sampleBuffer: CMSampleBuffer?
       
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: [timingInfos],
            sampleSizeEntryCount: 1,
            sampleSizeArray: [packet.count],
            sampleBufferOut: &sampleBuffer) == kCMBlockBufferNoErr,
            let derivedSampleBuffer = sampleBuffer else {
                return
        }
        
        guard let session = decompressionSession else {
            print("failed to fetch session")
            return
        }
        var flag = VTDecodeInfoFlags()
       // print(sampleBuffer)
        guard VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: derivedSampleBuffer,
            flags: [._EnableAsynchronousDecompression, ._EnableTemporalProcessing],
            frameRefcon: nil,
            infoFlagsOut: &flag) == 0 else {
                assertionFailure("fail decom")
                return }
        
        
    }
    
    
    private func updateDecompressionSession() {
        formatDescription = nil
        
        guard let spsData = sps, let ppsData =  pps else {
            print("param fail")
            return
        }
     //   print(spsData)
       // print(ppsData)
        let spsPointer = UnsafePointer<UInt8>(Array(spsData))
        let ppsPointer = UnsafePointer<UInt8>(Array(ppsData))
        
        let parameters = [spsPointer, ppsPointer]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(parameters)
        
        //let sizeOfParameters = [spsData.count, ppsData.count]
        // let sizeOfparameterSet = UnsafePointer<Int>(sizeOfParameters)
        
        
        let sizeParamArray = [spsData.count, ppsData.count]
        //CMVideoFormatDescriptionRef
        let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                         parameterSetCount: 2,
                                                                         parameterSetPointers: parameterSetPointers,
                                                                         parameterSetSizes: parameterSetSizes,
                                                                         nalUnitHeaderLength: 4,
                                                                         formatDescriptionOut: &formatDescription)
        guard let formatDescription = self.formatDescription,
            status == noErr
            else {
                print("desc fail\(status)")
                return
        }
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        var localSession: VTDecompressionSession?
        
        let decoderParameters = NSMutableDictionary()
        let decoderPixelBufferAttributes = NSMutableDictionary()
        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
        var didSessionCreate:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        )
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                         formatDescription: formatDescription,
                                                         decoderSpecification: decoderParameters,
                                                         imageBufferAttributes: decoderPixelBufferAttributes,
                                                         outputCallback: &didSessionCreate,
                                                         decompressionSessionOut: &localSession)
        if sessionStatus != noErr {
            assertionFailure("decomp Error")
        }
        decompressionSession = localSession
        
        
    }
    
    func makeNALUnits() -> [[UInt8]]? {
        var processing = false
        var mutableFrames = frames
        var nalu: [[UInt8]] = []
        
        let startCodeSize = self.startCode.count
        var startIndex = startCodeSize
        
        if mutableFrames.isEmpty  {
            return nil
        }
        
        if mutableFrames.count < startCodeSize + 1 || Array(mutableFrames[0..<startCode.count]) != self.startCode {
            return nil
        }

        //while true {
          //  print("count: \(mutableFrames.count)")
            while ((startIndex + startCodeSize - 1) < mutableFrames.count) {
                processing = true
                if Array(mutableFrames[startIndex..<(startIndex + startCodeSize)]) ==  self.startCode {
                    
                    var packet = Array(mutableFrames[0..<startIndex])
                    if startCode == VideoCodingConstant.startCodeBType {
                        packet.insert(0, at: 0)
                    }
                    
                    mutableFrames.removeSubrange(0..<startIndex)
                  //  mutableFrames = Array(mutableFrames[6...])
                    startIndex = startCodeSize
                    nalu.append(packet)
                }
                startIndex += 1
         //   }
        }
        if processing { nalu.append(mutableFrames) }
        return nalu
    }
}

func parseSEI(packet: [UInt8]) -> [[UInt8]]? {
    
    var mutableFrames = Array(packet[1...])
    var nalu: [[UInt8]] = []
    let startCode = VideoCodingConstant.startCodeBType
    let startCodeSize = 3
    var startIndex = startCodeSize
    var processing = false
    
    if mutableFrames.isEmpty  {
        return nil
    }
    
    if mutableFrames.count < startCodeSize + 1 || Array(mutableFrames[0..<startCode.count]) != VideoCodingConstant.startCodeBType {
        return nil
    }
    
    //while true {
   // print("count: \(mutableFrames.count)")
    while ((startIndex + startCodeSize - 1) < mutableFrames.count) {
        processing = true
        if Array(mutableFrames[startIndex..<(startIndex + startCodeSize)]) ==  VideoCodingConstant.startCodeBType {
            
            var packet = Array(mutableFrames[0..<startIndex])
            if startCode == VideoCodingConstant.startCodeBType {
                packet.insert(0, at: 0)
            }
            
            mutableFrames.removeSubrange(0..<startIndex)
            startIndex = startCodeSize
            processing = false
            nalu.append(packet)
        }
        startIndex += 1
        //   }
        
    }
    if processing { nalu.append(mutableFrames) }
    if !nalu.isEmpty { nalu.remove(at: 0) }
   // print(nalu)
    return nalu
}


struct VideoCodingConstant {
    
    static let startCodeAType: [UInt8] = [0,0,0,1]
    static let startCodeBType: [UInt8] = [0,0,1]
    
}


enum TypeOfNAL: UInt8 {
    case idr = 0x05
    case sps = 0x07
    case pps = 0x08
    case sei = 0x06
    case bpFrame = 0x01
}
