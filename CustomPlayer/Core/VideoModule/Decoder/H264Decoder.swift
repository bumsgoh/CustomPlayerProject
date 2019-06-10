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
  
    private let decodeQueue = DispatchQueue(label: "com.bumslap.h264DecoderQueue")
    let taskManager = TaskManager()
    let queue = OperationQueue()
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    var count = 0
    var sps: [UInt8]?
    var pps: [UInt8]?
    var sampleSizeArray: [Int] = []
    
    private var decodeCount = 0
    private var callbackCount = 0
    var hasDecodeDone: Bool {
        get {
            if decodeCount < callbackCount {
                callbackCount = 0
                return true
            } else {
                return false
            }
        }
    }
    var isESType: Bool = false
    
    weak var videoDecoderDelegate: MultiMediaVideoTypeDecoderDelegate?
    
    private lazy var startCode: [UInt8] = []
    
    var isBufferFull: Bool = false
    
    private var presentationTimeStamps: [CMSampleTimingInfo] = []
    
    private var callback: VTDecompressionOutputCallback = {(
        decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVBuffer?,
        presentationTimeStamp: CMTime,
        duration: CMTime) in
       
//        let decoder: H264Decoder = unsafeBitCast(decompressionOutputRefCon,
//                                                 to: H264Decoder.self)
        
//        let decoder: H264Decoder = Unmanaged<H264Decoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
//
//        guard let decodedBuffer: CVPixelBuffer = imageBuffer else { return }
//        let pointer = CVPixelBufferGetBaseAddress(decodedBuffer)
//        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
//                    duration: duration,
//                    presentationTimeStamp: presentationTimeStamp,
//                    decodeTimeStamp: CMTime.invalid
//                )
//
//                var formatDescription: CMVideoFormatDescription? = nil
//                CMVideoFormatDescriptionCreateForImageBuffer(
//                    allocator: kCFAllocatorDefault,
//                    imageBuffer: decodedBuffer,
//                    formatDescriptionOut: &formatDescription
//                )
//
//
//
//        var decodedSampleBuffer: CMSampleBuffer?
//
//        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil,
//                                                 imageBuffer: decodedBuffer,
//                                                 formatDescription: formatDescription!,
//                                                 sampleTiming: &timingInfo,
//                                                 sampleBufferOut: &decodedSampleBuffer)
//        guard let sample = decodedSampleBuffer else { return }
//       // decoder.callbackCount += 1
//       // print(decoder.callbackCount)
//        decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
//
//
//

        let decoder: H264Decoder = unsafeBitCast(decompressionOutputRefCon,
                                                         to: H264Decoder.self)
        guard let decodedBuffer: CVPixelBuffer = imageBuffer else { return }
        
         CVPixelBufferLockBaseAddress(decodedBuffer, CVPixelBufferLockFlags(rawValue: 0))
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
       
        CVPixelBufferUnlockBaseAddress(decodedBuffer, CVPixelBufferLockFlags(rawValue: 0))

      //  guard let sample = decodedSampleBuffer else { return }

        decoder.videoDecoderDelegate?.prepareToDisplay(with: decodedSampleBuffer!)
    }
  

    init() {}
    
    deinit {
        print("h264 deinit")
    }
    
    func suspendDecoding() {
        decodeQueue.suspend()
    }
    
    func resumeDecoding() {
        decodeQueue.resume()
    }
    
    func decode(nal: NALUnit, pts: CMSampleTimingInfo? = nil) {
        
        switch nal.type {
        case .idr:
            guard let pts = pts else { return }
            decodeVideoPacket(packet: nal.payload,
                              timingInfo: pts)
            
        case .slice:
            guard let pts = pts else { return }
            decodeVideoPacket(packet: nal.payload,
                              timingInfo: pts)
            
        case .sps:
            sps = nal.payload
            updateDecompressionSession()
            
        case .pps:
            pps = nal.payload
            updateDecompressionSession()
            
        default:
            break
           
        }
    }
    
    func setPTS(tiemStamps: [CMSampleTimingInfo]) {
        self.presentationTimeStamps = tiemStamps
    }
    
    func decode(frames: [UInt8], presentationTimestamps: [CMSampleTimingInfo]) {
        if !isESType { updateDecompressionSession() }

        if Array(frames[0...3]) == VideoCodingConstant.startCodeAType {
            self.startCode = VideoCodingConstant.startCodeAType
        } else if Array(frames[0...2]) == VideoCodingConstant.startCodeBType {
            self.startCode = VideoCodingConstant.startCodeBType
        } 
        
        var mutableFrames = frames
        var index = startCode.count
        var startCodeFlag = false
        var currentFrameSlices: [[UInt8]] = []
        var tempArray: [UInt8] = []
        var timingCount = 0
     //   decodeQueue.async { [weak self] in
      //      guard let self = self else { return}
        
        if !self.isESType {
            var count = 0
            var packets: [[UInt8]] = []
            
            while true {
                    if mutableFrames.isEmpty { break }
                    let packet = Array(mutableFrames[0..<self.sampleSizeArray[count]])
                    packets.append(packet)
                    mutableFrames.removeSubrange(0..<self.sampleSizeArray[count])
                    count += 1
            }
            
            for (index, packet) in packets.enumerated() {
              let task =  BlockOperation { [weak self] in
                    self?.decodeVideoPacket(packet: packet, timingInfo: presentationTimestamps[index])

                }
                
                taskManager.add(task: task)
            }
            return
        }
        var hasDone = false
        while !hasDone {
          //  if isBufferFull { continue }
            while Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeBType.count)])
                != VideoCodingConstant.startCodeBType
                && Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeAType.count)]) != VideoCodingConstant.startCodeAType {
                    
                    if index + VideoCodingConstant.startCodeAType.count > mutableFrames.count - 1
                        && !mutableFrames.isEmpty {
                        let nal = Array(mutableFrames[0...])
                        self.processNAL(nal: nal,
                                        targetSlices: &currentFrameSlices,
                                        dumpArray: &tempArray,
                                        timingInfo: presentationTimestamps[timingCount])
                    
                        
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
            
    
            self.processNAL(nal: nal,
                            targetSlices: &currentFrameSlices,
                            dumpArray: &tempArray,
                            timingInfo: presentationTimestamps[timingCount])
            
            if Array(mutableFrames[0..<3]) == VideoCodingConstant.startCodeBType {
                index = VideoCodingConstant.startCodeBType.count
                startCodeFlag = true
            } else {
                index = VideoCodingConstant.startCodeAType.count
                startCodeFlag = false
            }
        }
        
        self.decodeCount = currentFrameSlices.count
        for (index, nal) in currentFrameSlices.enumerated() {
         
           // let task = BlockOperation { [weak self] in
                self.decodeVideoPacket(packet: nal, timingInfo: presentationTimestamps[index])

          //  }
          //  taskManager.add(task: task)
        }
        return
    }
    
    private func processNAL(nal: [UInt8],
                    targetSlices: inout [[UInt8]],
                    dumpArray: inout [UInt8],
                    timingInfo: CMSampleTimingInfo) {
        let startCodeSize = 4
        var packet = nal
        if isESType {
            var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
            memcpy(&packet, &lengthOfNAL, startCodeSize)
        }
        let nalType = packet[4] & 0x1F
        
        switch nalType {
        case NALType.idr.rawValue, NALType.slice.rawValue:
            dumpArray.append(contentsOf: packet)
            
        case NALType.sps.rawValue:
            spsSize = packet.count - startCodeSize
            sps = Array(packet[startCodeSize..<packet.count])
            updateDecompressionSession()
        case NALType.pps.rawValue:
            ppsSize = packet.count - startCodeSize
            pps = Array(packet[startCodeSize..<packet.count])
            updateDecompressionSession()
            
        case NALType.aud.rawValue:
            if !dumpArray.isEmpty {
              //  self.decodeVideoPacket(packet: slice, timingInfo: timingInfo)
                targetSlices.append(dumpArray)
                dumpArray = []
            }
        default:
            break
        }
    }
    
    private func decodeVideoPacket(packet:[UInt8], timingInfo: CMSampleTimingInfo) {
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
       
        print(count)
        
        count += 1
        var sampleBuffer: CMSampleBuffer?
        var timing = timingInfo
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [packet.count],
            sampleBufferOut: &sampleBuffer) == kCMBlockBufferNoErr,
            let derivedSampleBuffer = sampleBuffer else {
                print("fail")
                return
        }
        print("sam count:\(count) \(sampleBuffer)")
        if !CMSampleBufferIsValid(sampleBuffer!){
            print("invalid")
            return
            
        }
    //    self.videoDecoderDelegate?.prepareToDisplay(with: sampleBuffer!)
        guard let session = decompressionSession else {
            print("failed to fetch session")
            return
        }
        var flag = VTDecodeInfoFlags()
        
        guard VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: derivedSampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            frameRefcon: nil,
            infoFlagsOut: &flag) == 0 else {
                assertionFailure("fail decom")
                return
        }
       
    }
    
    private func decodeVideoPacket(frames: [UInt8], presentationTimestamps: [CMSampleTimingInfo]) {
        var blockBuffer: CMBlockBuffer?
        let dataLength = frames.count
        let sizeArray = sampleSizeArray
        
        var mergedData = Data(frames)
        mergedData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            
            guard CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: bytes,
                blockLength: dataLength,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataLength,
                flags: 0,
                blockBufferOut: &blockBuffer) == kCMBlockBufferNoErr else {
                    return
                    
            }
        }
        
        
        var sampleBuffer: CMSampleBuffer?
        var timingEntries = presentationTimestamps.count
        
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: sizeArray.count,
            sampleTimingEntryCount: timingEntries,
            sampleTimingArray: presentationTimestamps,
            sampleSizeEntryCount: sizeArray.count,
            sampleSizeArray: sizeArray,
            sampleBufferOut: &sampleBuffer) == kCMBlockBufferNoErr,
            let derivedSampleBuffer = sampleBuffer else {
                return
        }
        guard let session = decompressionSession else {
            print("failed to fetch session")
            return
        }
        
        var flag = VTDecodeInfoFlags()
        
        guard VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: derivedSampleBuffer,
            flags: [._EnableAsynchronousDecompression, ._EnableTemporalProcessing],
            frameRefcon: nil,
            infoFlagsOut: &flag) == 0 else { return }
    }
    
    private func updateDecompressionSession() {
        formatDescription = nil
        
        guard let spsData = sps, let ppsData =  pps else {
            print("param fail")
            return
        }

        let spsPointer = UnsafePointer<UInt8>(Array(spsData))
        let ppsPointer = UnsafePointer<UInt8>(Array(ppsData))
        
        let parameters = [spsPointer, ppsPointer]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(parameters)

        let sizeParamArray = [spsData.count, ppsData.count]
        let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                         parameterSetCount: 2,
                                                                         parameterSetPointers: parameterSetPointers,
                                                                         parameterSetSizes: parameterSetSizes,
                                                                         nalUnitHeaderLength: 4,
                                                                         formatDescriptionOut: &formatDescription)
        guard let formatDescription = formatDescription,
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
        
        let decoderPixelBufferAttributes = NSMutableDictionary()
        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_32BGRA as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
       let attributes = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
            kCVPixelBufferOpenGLESCompatibilityKey: NSNumber(booleanLiteral: true)
        ]
        
        var didSessionCreate:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        )
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                         formatDescription: formatDescription,
                                                         decoderSpecification: attributes as CFDictionary?,
                                                         imageBufferAttributes: decoderPixelBufferAttributes,
                                                         outputCallback: &didSessionCreate,
                                                         decompressionSessionOut: &localSession)
        if sessionStatus != noErr {
            assertionFailure("decomp Error")
        }
        decompressionSession = localSession
    }
    
    
    func cleanUp() {
        sps = nil
        pps = nil
        
        formatDescription = nil
        decompressionSession = nil
        
        spsSize = 0
        ppsSize = 0
        
        startCode.removeAll()
    }
}

struct VideoCodingConstant {
    
    static let startCodeAType: [UInt8] = [0,0,0,1]
    static let startCodeBType: [UInt8] = [0,0,1]
    
}

