//
//  VideoFrameDecoder.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox


class VideoTrackDecoder: NSObject, TrackDecodable {
    
    private(set) var presentationTimestamp: [Int]
    private(set) var track: Track
    private(set) var samples: [[UInt8]]
    
    private var isPrepared: Bool = false
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    private var sps: [UInt8] = []
    private var pps: [UInt8] = []
    
    var sampleBuffers: CMSampleBuffer? = nil {
        didSet {
            
                isPrepared = true
                videoDelegate?.prepareToDisplay(with: sampleBuffers!)
            
        }
    }
    
    private var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    weak var videoDelegate: MultiMediaVideoTypeDecoderDelegate?
    weak var audioDelegate: MultiMediaAudioTypeDecoderDelegate? = nil
    
    init(track: Track, samples: [[UInt8]], presentationTimestamp: [Int]) {
        self.track = track
        self.samples = samples
        self.presentationTimestamp = presentationTimestamp
    }
    
    private var callback: VTDecompressionOutputCallback = {(
        decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVBuffer?,
        presentationTimeStamp: CMTime,
        duration: CMTime) in
        
        let decoder: VideoTrackDecoder = unsafeBitCast(decompressionOutputRefCon,
                                                       to: VideoTrackDecoder.self)
       /* decoder.didframeDecodeComplete(status,
                                    infoFlags: infoFlags,
                                    imageBuffer: imageBuffer,
                                    presentationTimeStamp: presentationTimeStamp,
                                    duration: duration)*/
    }
    
    func decodeTrack(samples frames: [[UInt8]], pts: [Int]) {
        
        var count = 0
        let duration = pts[1] * pts.count
        
        var timingInfos: [CMSampleTimingInfo] = []
        
        for i in pts {
            timingInfos.append(CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 24), presentationTimeStamp: CMTime(value: CMTimeValue(i), timescale: 30000), decodeTimeStamp: CMTime(value: 0, timescale: 0)))
        }
        let sizeArray = frames.map {
            $0.count
        }
        let packets: [UInt8] = Array(frames.joined())
        
        
        buildDecompressionSession()
       // for packet in frames {
          //  semaphore.wait()
            decodeVideoPacket(videoPacket: packets, timingInfos: timingInfos, sizeArray: sizeArray, duration: duration)
            count += 1
      //  }
        
    }
    
    
    private func decodeVideoPacket(videoPacket: [UInt8], timingInfos: [CMSampleTimingInfo],
                                   sizeArray: [Int] , duration: Int) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: videoPacket)
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: bufferPointer,
                                                        blockLength: videoPacket.count,
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: videoPacket.count,
                                                        flags: 0,
                                                        blockBufferOut: &blockBuffer)
        if status != kCMBlockBufferNoErr {
            return
        }
        
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = sizeArray
        var timingInfos = timingInfos
        
      /*  let timingInfo = [CMSampleTimingInfo(duration: CMTime(value: 0, timescale: 0), presentationTimeStamp: CMTime(value: Int64(pts), timescale: 24000), decodeTimeStamp: CMTime(value: 0, timescale: 0))]
         CMSampleBufferCreate*/
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                           dataBuffer: blockBuffer,
                                           formatDescription: formatDescription,
                                           sampleCount: sampleSizeArray.count,
                                           sampleTimingEntryCount: timingInfos.count,
                                           sampleTimingArray: timingInfos,
                                           sampleSizeEntryCount: sampleSizeArray.count,
                                           sampleSizeArray: sampleSizeArray,
                                           sampleBufferOut: &sampleBuffer)
        guard let buffer = sampleBuffer,
            let session = decompressionSession,
            status == kCMBlockBufferNoErr else {
                print("no session")
                return
        }
        
        guard let attachments: CFArray =
            CMSampleBufferGetSampleAttachmentsArray(buffer,
                                                    createIfNecessary: true)
            else { return }
        
        let attributes = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                       to: CFMutableDictionary.self)
        CFDictionarySetValue(attributes,
                             Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                             Unmanaged.passUnretained(kCFBooleanFalse).toOpaque())
        
        
        var flag = VTDecodeInfoFlags()
        
        status = VTDecompressionSessionDecodeFrame(session,
                                                   sampleBuffer: buffer,
                                                   flags: [._EnableAsynchronousDecompression,
                                                           ._EnableTemporalProcessing],
                                                   frameRefcon: nil,
                                                   infoFlagsOut: &flag)
        if status != noErr {
            return
        }
      //  semaphore.signal()
        sampleBuffers = buffer
       // print(buffer)
    }
    
    
    private func buildDecompressionSession() {
        
        formatDescription = nil
        
        let spsData = track.sequenceParameters.toUInt8Array
        let ppsData = track.pictureParameters.toUInt8Array
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
            status == noErr else {
                assertionFailure("format Desc failed")
                return
        }
        
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        
        var localSession: VTDecompressionSession?
        
        let decoderParameters = NSMutableDictionary()
        let decoderPixelBufferAttributes = NSMutableDictionary()
        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
       
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
    
    
    func didframeDecodeComplete(_ status:OSStatus,
                                infoFlags:VTDecodeInfoFlags,
                                imageBuffer:CVImageBuffer?,
                                presentationTimeStamp:CMTime,
                                duration:CMTime) {
       
        guard let imageBuffer:CVImageBuffer = imageBuffer,
            status == noErr else {
            return
        }
        
        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime(value: 0, timescale: 0)
            
        )
        
        var formatDescription:CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        var sampleBuffer:CMSampleBuffer? = nil
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let buffer:CMSampleBuffer = sampleBuffer else {
            return
        }
        
        
    }
    
    private func analyzeNALAndDecode(videoPacket: inout [UInt8]) {
        
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(videoPacket.count - 4)))
        
        memcpy(&videoPacket, &lengthOfNAL, 4)
        let typeOfNAL = videoPacket[4] & 0x1F
        
        switch typeOfNAL {
        case TypeOfNAL.idr.rawValue:
            buildDecompressionSession()
          //      decodeVideoPacket(videoPacket: videoPacket)
            
        case TypeOfNAL.sps.rawValue:
            spsSize = videoPacket.count - 4
            sps = Array(videoPacket[4..<videoPacket.count])
        case TypeOfNAL.pps.rawValue:
            ppsSize = videoPacket.count - 4
            pps = Array(videoPacket[4..<videoPacket.count])
        default:
         //   decodeVideoPacket(videoPacket: videoPacket)
            break
        }
    }
}

enum TypeOfNAL: UInt8 {
    case idr = 0x05
    case sps = 0x07
    case pps = 0x08
    case bpFrame
}
