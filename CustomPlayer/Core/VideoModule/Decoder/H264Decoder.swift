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

    var multiTrackThresHoldPts: CMTime?
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    var count = 0
    var sps: [UInt8]?
    var pps: [UInt8]?
 
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
            decodeTimeStamp: presentationTimeStamp
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

        guard let sample = decodedSampleBuffer else { return }
        
        if let threshold = decoder.multiTrackThresHoldPts {
            if decodedSampleBuffer!.presentationTimeStamp > threshold {
                 decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
            }
        } else {
            decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
        }
        print("\((decodedSampleBuffer!.presentationTimeStamp.seconds - 900) / 100))")
       // if (decodedSampleBuffer!.presentationTimeStamp.seconds - 900) / 100 > 5 {
        
      //  }
        print("out")
    }
  

    init() {}
    
    deinit {
        print("h264 deinit")
    }
    
    func decode(nal: NALUnit, pts: CMSampleTimingInfo? = nil) {
        
        switch nal.type {
        case .idr:
            guard let pts = pts else {
                assertionFailure("no pts")
                return
            }
          
            decodeVideoPacket(packet: nal.payload,
                                  timingInfo: pts)
       
           
            print("idr detected")
        case .slice:
            guard let pts = pts else {
                assertionFailure("no pts")
                return
            }
            
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
    
    
    private func decodeVideoPacket(packet:[UInt8], timingInfo: CMSampleTimingInfo) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: packet)
        var blockBuffer: CMBlockBuffer?
        
       // print("packet in: \(packet) with pts\(timingInfo)")
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
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, createIfNecessary: true) {
            let dictionary = unsafeBitCast(
                CFArrayGetValueAtIndex(attachments, 0),
                to: CFMutableDictionary.self)
            
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        
       // print("sam count:\(count) \(sampleBuffer)")
       
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
                return
        }
        
         VTDecompressionSessionWaitForAsynchronousFrames(session)
       
    }
    
    private func decodeVideoPacket(frames: [UInt8], presentationTimestamps: [CMSampleTimingInfo]) {
        var blockBuffer: CMBlockBuffer?
        let dataLength = frames.count
        let sizeArray = [Int]()
        
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
        
//        let decoderPixelBufferAttributes = NSMutableDictionary()
//        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_32BGRA as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
//
//       let attributes = [
//            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
//            kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
//            kCVPixelBufferOpenGLESCompatibilityKey: NSNumber(booleanLiteral: true)
//        ]
//
        
        kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID
        
        let decoderSpecification: [NSString: Any] = [
            //kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID: kCFBooleanTrue!,
            kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID: kCFBooleanFalse!
        ]
        
        // Prepare default attributes
        let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let defaultAttr: [NSString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_422YpCbCr8),
            kCVPixelBufferWidthKey: Int(dimensions.width),
            kCVPixelBufferHeightKey: Int(dimensions.height)
            //, kCVPixelBufferIOSurfacePropertiesKey: [:]
            , kCVPixelBufferOpenGLCompatibilityKey: true
            //, kCVPixelBufferMetalCompatibilityKey: true // __MAC_10_11
            //, kCVPixelBufferOpenGLTextureCacheCompatibilityKey: true // __MAC_10_11
        ]
        
        
        var didSessionCreate:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        )
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                         formatDescription: formatDescription,
                                                         decoderSpecification: decoderSpecification as CFDictionary,
                                                         imageBufferAttributes: defaultAttr as CFDictionary,
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

