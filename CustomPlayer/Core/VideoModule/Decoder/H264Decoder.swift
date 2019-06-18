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

    var multiTrackThresHoldPts: CMTimeValue?
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
 
    var sps: [UInt8]?
    var pps: [UInt8]?
 
    weak var videoDecoderDelegate: MultiMediaVideoTypeDecoderDelegate?
    
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
        
         print(" pts is \(decoder.multiTrackThresHoldPts)")
        if let threshold = decoder.multiTrackThresHoldPts {
            if timingInfo.presentationTimeStamp.value < threshold {
                print("calc")
                
            } else {
                      decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
            }
        } else {
            // multiTrackThresHoldPts = nil
                   decoder.videoDecoderDelegate?.prepareToDisplay(with: sample)
        }
        

        
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
    
    func setThreshold(time: CMTimeValue) {

        self.multiTrackThresHoldPts = time
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

        guard let session = decompressionSession else {
            print("failed to fetch session")
            return
        }
        
        var flag = VTDecodeInfoFlags()
        
        var decodeFlag: VTDecodeFrameFlags = VTDecodeFrameFlags()
        
       
       
          decodeFlag = [._EnableAsynchronousDecompression, ._EnableTemporalProcessing]
        guard VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: derivedSampleBuffer,
            flags: decodeFlag,
            frameRefcon: nil,
            infoFlagsOut: &flag) == 0 else {
                assertionFailure("fail decom")
                return
        }
        
         //VTDecompressionSessionWaitForAsynchronousFrames(session)
       
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
        
        let decoderSpecification: [NSString: Any] = [
            //kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID: kCFBooleanTrue!,
            kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID: kCFBooleanTrue!
        ]
        

     //   let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let defaultAttr: [NSString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
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
        
       // multiTrackThresHoldPts = nil
    
    }
}

struct VideoCodingConstant {
    
    static let startCodeAType: [UInt8] = [0,0,0,1]
    static let startCodeBType: [UInt8] = [0,0,1]
    
}

