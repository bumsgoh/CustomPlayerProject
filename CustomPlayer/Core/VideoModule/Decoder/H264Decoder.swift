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
    
    private var buffers: [CMSampleBuffer] = []
    private var minimumGroupOfPictures: Int = 12
    
    private let lockQueue = DispatchQueue(label: "com.bumslap.h264DecoderLock")
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    var sizeArray: [Int] = []
    private var sps: [UInt8]?
    private var pps: [UInt8]?
    
    private var pictureCount = -1
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
        
        guard let sample = decodedSampleBuffer else { return }
        
        decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
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
      //  guard let nalu = makeNALUnits() else { return }
        var currentFrameSlices = [UInt8]()
        makeNALUnits()?.forEach {
            var packet = $0
            var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
            
            memcpy(&packet, &lengthOfNAL, 4)
            
            let typeOfNAL = packet[4] & 0x1F
            
            switch typeOfNAL {
            case NALType.idr.rawValue, NALType.slice.rawValue:
                // print(packet.tohexNumbers)
                currentFrameSlices.append(contentsOf: packet)
            case NALType.sps.rawValue:
                spsSize = packet.count - 4
                sps = Array(packet[4..<packet.count])
                updateDecompressionSession()
            case NALType.pps.rawValue:
                ppsSize = packet.count - 4
                pps = Array(packet[4..<packet.count])
                updateDecompressionSession()
            case NALType.aud.rawValue:
                pictureCount += 1
                decodeVideoPacket(packet: currentFrameSlices, timingInfo: presentationTimestamps[pictureCount])
                currentFrameSlices = []
            default:
                break
            }
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
        
        var sampleBuffer: CMSampleBuffer?
        let timing = timingInfo
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: [timing],
            sampleSizeEntryCount: 1,
            sampleSizeArray: [packet.count],
            sampleBufferOut: &sampleBuffer) == kCMBlockBufferNoErr,
            let derivedSampleBuffer = sampleBuffer else {
                print("fail")
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
    
    
    
    func makeNALUnits() -> [[UInt8]]? {
        var mutableFrames = frames
        var index = startCode.count
        var nal = [UInt8]()
        var nalu: [[UInt8]] = []
        var startCodeFlag = false
        
        while true {
            while Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeBType.count)])
                != VideoCodingConstant.startCodeBType
                && Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeAType.count)]) != VideoCodingConstant.startCodeAType {
                if index + VideoCodingConstant.startCodeAType.count > mutableFrames.count - 1 {
                    nalu.append(Array(mutableFrames[0...]))
                    return nalu
                }
                index += 1
                
            }
            nal = Array(mutableFrames[0..<index])
            mutableFrames.removeSubrange(0..<index)
            if startCodeFlag { nal.insert(0, at: 0) }
            nalu.append(nal)
            if Array(mutableFrames[0..<3]) == VideoCodingConstant.startCodeBType {
                index = VideoCodingConstant.startCodeBType.count
                startCodeFlag = true
            } else {
                index = VideoCodingConstant.startCodeAType.count
                startCodeFlag = false
            }
        }
        return nalu
    }
    
    func decode1(frames: [UInt8], presentationTimestamps: [CMSampleTimingInfo]) {
        var mutableFrames = frames
        var index = startCode.count
        var startCodeFlag = false
        var currentFrameSlices: [UInt8] = []
        var timingCount = 0
        
        while true {
            while Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeBType.count)])
                != VideoCodingConstant.startCodeBType
                && Array(mutableFrames[index..<(index + VideoCodingConstant.startCodeAType.count)]) != VideoCodingConstant.startCodeAType {
                    if index + VideoCodingConstant.startCodeAType.count > mutableFrames.count - 1 {
                        let nal = Array(mutableFrames[0...])
                        processNAL(nal: nal,
                                   targetSlices: &currentFrameSlices,
                                   timingInfoCount: &timingCount,
                                   timingInfo: presentationTimestamps[timingCount])
                        return
                    }
                index += 1
            }
            var nal = Array(mutableFrames[0..<index])
            mutableFrames.removeSubrange(0..<index)
            
            if startCodeFlag {
                nal.insert(0, at: 0)
            }
            processNAL(nal: nal,
                       targetSlices: &currentFrameSlices,
                       timingInfoCount: &timingCount,
                       timingInfo: presentationTimestamps[timingCount])
            
            if Array(mutableFrames[0..<3]) == VideoCodingConstant.startCodeBType {
                index = VideoCodingConstant.startCodeBType.count
                startCodeFlag = true
            } else {
                index = VideoCodingConstant.startCodeAType.count
                startCodeFlag = false
            }
        }
    }
    
    func processNAL(nal: [UInt8],
                    targetSlices: inout [UInt8],
                    timingInfoCount: inout Int,
                    timingInfo: CMSampleTimingInfo) {
        
        let startCodeSize = 4
        var packet = nal
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(packet.count - 4)))
        
        memcpy(&packet, &lengthOfNAL, startCodeSize)
        
        let nalType = packet[4] & 0x1F
        
        switch nalType {
        case NALType.idr.rawValue, NALType.slice.rawValue:
            // print(packet.tohexNumbers)
            targetSlices.append(contentsOf: packet)
        case NALType.sps.rawValue:
            spsSize = packet.count - startCodeSize
            sps = Array(packet[startCodeSize..<packet.count])
        case NALType.pps.rawValue:
            ppsSize = packet.count - startCodeSize
            pps = Array(packet[startCodeSize..<packet.count])
            updateDecompressionSession()
        case NALType.aud.rawValue:
            timingInfoCount += 1
            decodeVideoPacket(packet: targetSlices, timingInfo: timingInfo)
            targetSlices = []
        default:
            break
        }
    
    }
    
}


struct VideoCodingConstant {
    
    static let startCodeAType: [UInt8] = [0,0,0,1]
    static let startCodeBType: [UInt8] = [0,0,1]
    
}

